import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'content_safety.dart';
import 'source_collector.dart';
import 'supabase_service.dart';

class ContentPipeline {
  static final ContentPipeline _instance = ContentPipeline._();
  factory ContentPipeline() => _instance;
  ContentPipeline._();

  final _ai = AiService();
  final _safety = ContentSafetyFilter();
  final _supabase = SupabaseService();

  final Set<String> _processedHashes = {};
  final Map<String, Map<String, dynamic>> _summaryCache = {};

  // ── Step 1: Pre-filter (no LLM) ──

  List<Map<String, dynamic>> preFilter(List<Map<String, dynamic>> candidates) {
    final seen = <String>{};
    final filtered = <Map<String, dynamic>>[];

    for (final item in candidates) {
      final url = item['url'] as String? ?? '';
      final urlHash = _hash(url);

      if (_processedHashes.contains(urlHash)) continue;
      if (seen.contains(urlHash)) continue;
      seen.add(urlHash);

      final title = item['title'] as String? ?? '';
      if (title.length < 5) continue;

      filtered.add(item);
    }

    debugPrint('[KOK Pipeline] Pre-filter: ${candidates.length} → ${filtered.length} candidates');
    return filtered;
  }

  // ── Step 2: Cluster similar issues ──

  Future<List<Map<String, dynamic>>> clusterIssues(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.length <= 3) {
      return items.map((i) => {'items': [i], 'representative': i}).toList();
    }

    final titles = items.map((i) => i['title'] as String? ?? '').toList();
    final titlesStr = titles.asMap().entries.map((e) => '${e.key}: ${e.value}').join('\n');

    try {
      _groqCallCount++;
      final result = await _ai.callGroqJson('''
Group these K-pop news titles into issue clusters. Titles about the same event/topic go together.

$titlesStr

Output JSON:
{"clusters": [[0,3,5], [1,2], [4]]}

Each array contains indices of titles that belong to the same issue. Maximum 8 clusters.
''', maxTokens: 512);

      final clusters = (result['clusters'] as List?)?.map((cluster) {
        final indices = (cluster as List).map((i) => (i as num).toInt()).toList();
        final clusterItems = indices
            .where((i) => i < items.length)
            .map((i) => items[i])
            .toList();
        if (clusterItems.isEmpty) return null;
        return {
          'items': clusterItems,
          'representative': clusterItems.first,
        };
      }).whereType<Map<String, dynamic>>().toList();

      debugPrint('[KOK Pipeline] Clustered into ${clusters?.length ?? 0} groups');
      return clusters ?? items.map((i) => {'items': [i], 'representative': i}).toList();
    } catch (e) {
      debugPrint('[KOK Pipeline] Clustering failed, using individual items: $e');
      return items.map((i) => {'items': [i], 'representative': i}).toList();
    }
  }

  // ── Step 3: Score importance ──
  // feed_score + 클러스터 크기 보너스

  int scoreImportance(Map<String, dynamic> cluster) {
    final items = cluster['items'] as List;
    final rep = cluster['representative'] as Map<String, dynamic>;

    int score = rep['_relevance'] as int? ?? 0;

    // 클러스터 보너스: 같은 이슈의 기사가 많으면 더 핫한 이슈
    score += (items.length - 1) * 3;

    // 댓글 보너스
    final comments = rep['comments'] as List?;
    if (comments != null && comments.isNotEmpty) {
      score += comments.length.clamp(0, 10) * 2;
    }

    return score;
  }

  // ── Step 4: Groq — summarize + classify ──

  Future<Map<String, dynamic>> groqSummarize({
    required String title,
    required String snippet,
    required List<String> comments,
  }) async {
    final contentHash = _hash('$title$snippet');
    if (_summaryCache.containsKey(contentHash)) {
      return _summaryCache[contentHash]!;
    }

    final safety = _safety.checkKoreanContent(title, snippet);
    if (safety.level == SafetyLevel.blocked) {
      debugPrint('[KOK Pipeline] Blocked by safety: ${safety.reason}');
      return {'blocked': true, 'reason': safety.reason};
    }

    final sanitizedComments = comments
        .take(15)
        .map((c) => c.length > 160 ? '${c.substring(0, 160)}...' : c)
        .map((c) => _safety.sanitizeComment(c))
        .toList();

    final hasRealComments = sanitizedComments.isNotEmpty;
    final commentsSection = hasRealComments
        ? 'Real comments collected (${sanitizedComments.length}):\n${sanitizedComments.join('\n')}'
        : 'No real comments collected for this article.';

    _groqCallCount++;
    debugPrint('[KOK Pipeline] Groq call #$_groqCallCount: "$title"');

    final nameMap = SourceCollector.buildNameMappingPrompt();

    final result = await _ai.callGroqJson('''
너는 한국 K-pop 여론 분석 전문가야. 아래 한국어 뉴스를 분석해.
중요: 해외 K-pop 팬들이 "진짜 흥미로워하고 클릭할만한" 뉴스인지를 판단 기준으로 삼아라. 사소하거나 시시한 뉴스는 is_relevant: false 처리해라.

$nameMap

제목: ${title.length > 120 ? '${title.substring(0, 120)}...' : title}
내용: ${snippet.length > 400 ? '${snippet.substring(0, 400)}...' : snippet}

$commentsSection

JSON으로 출력:
{
  "is_relevant": true,
  "issue_summary_ko": "왜 이게 화제인지, 맥락과 의미를 담은 한국어 요약 (2~3문장). 단순 사실 나열 X. 팬이 아닌 사람도 이해할 수 있도록 배경 포함.",
  "reaction_tone": "supportive/critical/mixed/amused/neutral",
  "issue_tags": ["COMEBACK"],
  "artist_tags": ["BTS"],
  "has_real_comments": $hasRealComments,
  "safety_flag": "safe",
  "importance_score": 7
}

규칙:
- is_relevant 판단 기준 (엄격하게):
  * true: 유명 K-pop 아이돌/소속사의 컴백, 논란, 계약, 수상, 차트 등 팬들이 열광할 뉴스
  * false: 마이너 소식, 시시콜콜한 일상 TMI, 단순 일정 공지, 광고성 기사, K-pop과 무관한 연예 뉴스
  * false: 제목만 자극적이고 내용이 없는 낚시 기사
- issue_summary_ko: "왜 한국에서 화제인지"를 설명. 맥락, 배경, 의미를 담아라.
- reaction_tone (가장 중요!! "neutral"을 기본값으로 쓰지 마라):
  * "supportive": 팬 응원/기대/자랑이 70%+ (컴백, 수상, 선행, 성과)
  * "critical": 비판/분노가 70%+ (논란, 스캔들, 갑질)
  * "mixed": 찬반 갈림 — 긍정과 부정이 모두 25%+ 존재 (열애, 이적, 논쟁, 팬덤 갈등)
  * "amused": 웃기거나 밈화가 70%+ (예능, 에피소드, TMI)
  * "neutral": 위 4가지 어디에도 해당 안 되는 순수 정보만 (거의 사용 X)
- issue_tags: COMEBACK, CHART, AWARD, AGENCY, CONTRACT, CONTROVERSY, FANDOM, MILITARY, RELATIONSHIP, LEGAL, SOCIAL_MEDIA, PERFORMANCE, COLLABORATION, BRAND_DEAL, VARIETY_SHOW, WORLD_TOUR, DEBUT, DISBANDMENT, SOLO, OST 중 선택
- artist_tags: 공식 영어 이름 사용 (ARTIST NAME MAP 참고)
- importance_score: 1~10. 7 이상이면 진짜 핫한 이슈만.
- 절대 존재하지 않는 댓글이나 반응을 만들어내지 마라.
''', maxTokens: 1024);

    _summaryCache[contentHash] = result;
    return result;
  }

  // ── Step 5: EN/ES 카드 생성 (Gemini → Cerebras → Groq) ──
  // 실제 댓글 데이터만 전달. AI가 숫자/소스를 만들어내지 않도록 함.

  Future<Map<String, dynamic>> generateCard({
    required String koreanSummary,
    required String reactionTone,
    required List<Map<String, dynamic>> realComments,
    required List<Map<String, dynamic>> blogReactions,
    required List<String> issueTags,
    required List<String> artistTags,
    required List<Map<String, String>> sources,
  }) async {
    final hasComments = realComments.isNotEmpty;
    final reactionsStr = hasComments
        ? realComments.take(5).map((c) =>
            '- "${c['text']}" (${c['likes']} likes, from ${c['source']})').join('\n')
        : '';

    final hasBlogReactions = blogReactions.isNotEmpty;
    final blogStr = hasBlogReactions
        ? blogReactions.take(8).map((r) =>
            '- [${r['source']}] "${r['text']}"').join('\n')
        : '';

    final hasAnyReaction = hasComments || hasBlogReactions;

    final sourcesStr = sources
        .map((s) => '- ${s['title']}: ${s['url']}')
        .join('\n');

    final nameMap = SourceCollector.buildNameMappingPrompt();
    _geminiCallCount++;

    final prompt = '''
You are KOK's star writer — THE go-to voice for international K-pop fans who want the REAL Korean perspective. You write like a sharp, witty, bilingual insider who actually lives in Korea and breathes K-pop culture. Your writing is so good that fans screenshot and share your articles.

$nameMap

---

[YOUR WRITING STYLE]
- Headlines that make people STOP scrolling. Use power words, tension, or intrigue. Never boring. Never generic.
- "What happened" should read like a friend spilling the tea — concise but juicy. Include specific details that make it real.
- "Why it matters" must connect to the BIGGER PICTURE — fandom dynamics, industry power moves, cultural shifts. Never just restate what happened.
- "Korean reaction summary" is your signature section. Paint a VIVID picture of how Korean internet is reacting. Use specific community vibes: "Korean fans on TheQoo are torn between...", "Naver comment sections are flooded with...", "The general Korean public sentiment is shifting toward...". Make the reader FEEL the atmosphere.
- "Context for fans" — drop genuine cultural knowledge bombs. Things that Korean fans instinctively understand but international fans would miss entirely.
- Every sentence must earn its place. Cut filler. Maximize impact.

---

[INPUT]
Korean Summary: $koreanSummary
Reaction Tone: $reactionTone
${hasComments ? 'REAL collected comments (translate these faithfully, preserve the raw energy):\n$reactionsStr' : ''}
${hasBlogReactions ? 'Korean public reactions from blogs/communities (use these to write a VIVID korean_reaction_summary):\n$blogStr' : ''}
${!hasAnyReaction ? 'No direct comments or reactions were collected. Write korean_reaction_summary by channeling how Korean communities (TheQoo, Nate Pann, DC Inside, Naver) would typically react to this type of news. Be specific about the community vibe, but do NOT fabricate exact quotes or numbers.' : ''}
Tags: ${issueTags.join(', ')}
Artists: ${artistTags.join(', ')}
Sources:
$sourcesStr

---

[OUTPUT — JSON]
{
  "issue_title_en": "Magnetic headline that hooks instantly. Use tension, stakes, or intrigue. Max 90 chars. NO generic titles like 'X makes waves' or 'X sparks buzz'.",
  "issue_title_es": "Spanish — equally punchy, natural LatAm Gen-Z tone",
  "what_happened_en": "The tea, served hot. Specific details, not vague summaries. Write like you're texting your best friend the breaking news. Max 350 chars.",
  "what_happened_es": "Spanish version — same energy, natural flow",
  "why_it_matters_en": "Connect to the bigger picture. Why should fans care beyond the surface? What does this mean for the group/industry/fandom? Max 350 chars.",
  "why_it_matters_es": "Spanish version",
  "korean_reaction_summary_en": "Paint the scene of Korean internet reacting. Be VIVID and SPECIFIC. Reference community vibes (not fabricated quotes). What's the dominant feeling? Any memorable takes? Is the mood shifting? Max 500 chars.",
  "korean_reaction_summary_es": "Spanish version",
  ${hasComments ? '"top_reactions": [\n    {"content_en": "Faithful translation preserving the commenter\'s raw voice and tone", "content_es": "Spanish", "likes": EXACT_NUMBER_FROM_INPUT, "source": "EXACT_SOURCE_FROM_INPUT"}\n  ],' : '"top_reactions": [],'}
  "context_for_fans_en": "Cultural insider knowledge. Korean social norms, industry politics, historical context, or fan culture nuances that international fans genuinely wouldn't know. Make it enlightening. Max 400 chars.",
  "context_for_fans_es": "Spanish version",
  "sentiment": "$reactionTone"
}

---

HARD RULES (violating these = failed output):
1. ARTIST NAMES: Use EXACT official English names from ARTIST NAME MAP. Never guess. Never transliterate.
2. top_reactions: ONLY translate REAL comments provided above. EXACT likes + source. ZERO fabrication.
3. No real comments provided → EMPTY top_reactions array [].
4. NEVER fabricate quotes, numbers, or source names.
5. NO filler phrases: "sparks buzz", "making waves", "takes the internet by storm", "fans are excited" — these are BANNED. Be specific instead.
6. Spanish must sound like a real LatAm Gen-Z K-pop fan wrote it — NOT Google Translate.
7. Every field must deliver genuine value. If you can't write something interesting, write something insightful.
8. CONTENT ALIGNMENT: The title, what_happened, korean_reaction_summary, top_reactions, and why_it_matters MUST all be about the SAME specific topic. If the topic is about Artist X, NEVER mention unrelated Artist Y in the title.
9. top_reactions must be direct translations of the real comments about THIS topic. They must align with the mood described in korean_reaction_summary.
10. TRANSLATION QUALITY: Translate Korean comments naturally — not literal word-by-word. Preserve the commenter's intent, humor, and specific references. "미쳤다" = "insane/crazy (as praise)", "개예쁘다" = "ridiculously pretty", etc.
''';

    final result = await _ai.generateCardJson(prompt, maxTokens: 3000);

    final titleEn = result['issue_title_en'] as String? ?? '';
    final bodyEn = result['what_happened_en'] as String? ?? '';
    final outputSafety = _safety.checkTranslatedContent('$titleEn $bodyEn');
    if (outputSafety.level == SafetyLevel.blocked) {
      return {'blocked': true, 'reason': outputSafety.reason};
    }

    if (result['sentiment'] == 'divided') {
      result['sentiment'] = 'mixed';
    }

    return result;
  }

  // ── Full Pipeline ──

  Future<List<Map<String, dynamic>>> processNewsBatch(
    List<Map<String, dynamic>> rawCandidates,
  ) async {
    _ai.resetCooldowns();
    debugPrint('[KOK Pipeline] Starting batch: ${rawCandidates.length} raw candidates');

    final filtered = preFilter(rawCandidates);
    if (filtered.isEmpty) {
      debugPrint('[KOK Pipeline] No new candidates after filtering');
      return [];
    }

    final clusters = await clusterIssues(filtered);

    final scored = clusters.map((c) => {
      ...c,
      'score': scoreImportance(c),
    }).toList()
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    debugPrint('[KOK Pipeline] Top scores: ${scored.take(5).map((s) => s['score']).toList()}');

    final topIssues = scored.take(5).toList();
    final cards = <Map<String, dynamic>>[];

    for (int i = 0; i < topIssues.length; i++) {
      final cluster = topIssues[i];
      try {
        final rep = cluster['representative'] as Map<String, dynamic>;
        final title = rep['title'] as String? ?? '';
        final snippet = rep['snippet'] as String? ?? '';
        final comments = List<String>.from(rep['comments'] ?? []);

        // 제목이 너무 짧거나 의미없으면 토큰 낭비 방지
        if (title.length < 10) continue;

        debugPrint('[KOK Pipeline] Processing ${i + 1}/${topIssues.length}: "$title" (${comments.length} comments)');

        final summary = await groqSummarize(
          title: title,
          snippet: snippet,
          comments: comments,
        );

        if (summary['blocked'] == true) {
          debugPrint('[KOK Pipeline] Blocked: ${summary['reason']}');
          continue;
        }
        if (summary['is_relevant'] != true) {
          debugPrint('[KOK Pipeline] Not relevant, skipping');
          continue;
        }
        if (summary['safety_flag'] == 'blocked') {
          debugPrint('[KOK Pipeline] Safety blocked');
          continue;
        }

        final items = cluster['items'] as List;
        final sources = items
            .map((item) => {
                  'title': (item as Map<String, dynamic>)['title']?.toString() ?? '',
                  'url': item['url']?.toString() ?? '',
                })
            .toList();

        // Gemini rate limit 방지: 호출 간 3초 간격
        if (i > 0) await Future.delayed(const Duration(seconds: 3));

        // 실제 댓글 데이터 (좋아요 수, 소스 포함) 가져오기
        final realCommentData = List<Map<String, dynamic>>.from(
          rep['comment_data'] ?? [],
        );

        // 블로그/카페에서 여론 반응 수집
        List<Map<String, dynamic>> blogReactions = [];
        try {
          blogReactions = await SourceCollector().collectReactions(title);
          debugPrint('[KOK Pipeline] Blog/Cafe reactions: ${blogReactions.length}');
        } catch (e) {
          debugPrint('[KOK Pipeline] Blog/Cafe collection failed: $e');
        }

        final card = await generateCard(
          koreanSummary: summary['issue_summary_ko'] as String? ?? '',
          reactionTone: summary['reaction_tone'] as String? ?? 'neutral',
          realComments: realCommentData,
          blogReactions: blogReactions,
          issueTags: List<String>.from(summary['issue_tags'] ?? []),
          artistTags: List<String>.from(summary['artist_tags'] ?? []),
          sources: sources,
        );

        if (card['blocked'] == true) {
          debugPrint('[KOK Pipeline] Card blocked: ${card['reason']}');
          continue;
        }

        // ── Quality Gate: 허접한 게시물 차단 ──
        final titleEn2 = (card['issue_title_en'] as String? ?? '').trim();
        final whatEn = (card['what_happened_en'] as String? ?? '').trim();
        final reactionEn = (card['korean_reaction_summary_en'] as String? ?? '').trim();
        final totalSources = realCommentData.length + blogReactions.length;

        if (titleEn2.length < 15) {
          debugPrint('[KOK Pipeline] Quality gate: title too short ("$titleEn2")');
          continue;
        }
        if (whatEn.length < 50) {
          debugPrint('[KOK Pipeline] Quality gate: what_happened too thin (${whatEn.length} chars)');
          continue;
        }
        if (reactionEn.length < 80) {
          debugPrint('[KOK Pipeline] Quality gate: reaction summary too thin (${reactionEn.length} chars)');
          continue;
        }

        // 최소 반응 소스 1개 이상 있어야 게시 (유저 경험 최우선)
        if (totalSources == 0 && realCommentData.isEmpty && blogReactions.isEmpty) {
          debugPrint('[KOK Pipeline] Quality gate: 0 sources — not publishing');
          continue;
        }

        // 금지 표현 체크 (filler 문구)
        final fillerPatterns = RegExp(
          r'(sparks? buzz|mak(es?|ing) waves|takes? the internet by storm|breaks? the internet|fans are excited)',
          caseSensitive: false,
        );
        if (fillerPatterns.hasMatch(titleEn2)) {
          debugPrint('[KOK Pipeline] Quality gate: filler title ("$titleEn2")');
          continue;
        }

        card['issue_tags'] = summary['issue_tags'];
        // Groq가 한국어명을 반환할 수 있으므로 공식 영어명으로 변환
        final rawArtistTags = List<String>.from(summary['artist_tags'] ?? []);
        card['artist_tags'] = rawArtistTags
            .map((tag) => SourceCollector.getOfficialName(tag))
            .toList();
        card['reaction_sample_size'] = realCommentData.length + blogReactions.length;
        card['original_sources'] = sources;
        card['safety_level'] = summary['safety_flag'];

        // 이미지: 클러스터 내 YouTube 썸네일 URL 탐색 (DB에 URL만 저장)
        String imageUrl = rep['image_url'] as String? ?? '';
        if (imageUrl.isEmpty) {
          for (final item in items) {
            final url = (item as Map<String, dynamic>)['image_url'] as String? ?? '';
            if (url.isNotEmpty) { imageUrl = url; break; }
          }
        }
        if (imageUrl.isNotEmpty) {
          card['image_url'] = imageUrl;
        }

        // 빈 콘텐츠 top_reactions 필터링
        if (card['top_reactions'] is List) {
          card['top_reactions'] = (card['top_reactions'] as List)
              .where((r) {
                final en = (r['content_en'] as String? ?? '').trim();
                final es = (r['content_es'] as String? ?? '').trim();
                return en.isNotEmpty || es.isNotEmpty;
              })
              .toList();
        }

        try {
          final articleId = await _supabase.insertPipelineArticle(card);
          debugPrint('[KOK Pipeline] Saved: "${card['issue_title_en']}" (id=$articleId)');
        } catch (e) {
          debugPrint('[KOK Pipeline] DB save failed: $e');
          continue;
        }

        cards.add(card);

        for (final item in items) {
          final url = (item as Map<String, dynamic>)['url'] as String? ?? '';
          _processedHashes.add(_hash(url));
        }
      } catch (e, stackTrace) {
        debugPrint('[KOK Pipeline] Item ${i + 1} failed: $e');
        debugPrint('[KOK Pipeline] Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
        continue;
      }
    }

    debugPrint('[KOK Pipeline] Batch complete: ${cards.length} articles generated');
    return cards;
  }

  // ── Utilities ──

  int _groqCallCount = 0;
  int _geminiCallCount = 0;

  int get groqCallCount => _groqCallCount;
  int get geminiCallCount => _geminiCallCount;

  void resetCallCounts() {
    _groqCallCount = 0;
    _geminiCallCount = 0;
  }

  void loadProcessedHashes(Set<String> hashes) {
    _processedHashes.addAll(hashes);
    debugPrint('[KOK Pipeline] Loaded ${hashes.length} processed hashes');
  }

  String hashUrl(String url) => _hash(url);

  String _hash(String input) => md5.convert(utf8.encode(input)).toString();

  void clearCache() => _summaryCache.clear();
}
