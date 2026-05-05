import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'content_safety.dart';
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
  // SourceCollector의 relevance score + 클러스터 크기 + 댓글 보너스

  int scoreImportance(Map<String, dynamic> cluster) {
    final items = cluster['items'] as List;
    final rep = cluster['representative'] as Map<String, dynamic>;

    // 소스 수집 단계에서 이미 계산된 relevance score 활용
    int score = rep['_relevance'] as int? ?? 0;

    // 같은 이슈의 기사 수 보너스 (클러스터 크기)
    score += items.length * 5;

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

    final result = await _ai.callGroqJson('''
너는 한국 K-pop 여론 분석 전문가야. 아래 한국어 뉴스를 분석해.

제목: ${title.length > 120 ? '${title.substring(0, 120)}...' : title}
내용: ${snippet.length > 400 ? '${snippet.substring(0, 400)}...' : snippet}

$commentsSection

JSON으로 출력:
{
  "is_relevant": true,
  "issue_summary_ko": "핵심을 짚는 한국어 요약 (2~3문장, 맥락 포함)",
  "reaction_tone": "supportive/critical/divided/amused/neutral",
  "issue_tags": ["COMEBACK"],
  "artist_tags": ["BTS"],
  "has_real_comments": $hasRealComments,
  "safety_flag": "safe",
  "importance_score": 7
}

규칙:
- is_relevant: K-pop 아이돌, 소속사, 업계 뉴스면 true
- issue_summary_ko: "왜 이게 화제인지"를 담아야 함. 단순 사실 나열 X, 맥락과 의미 포함 O
- reaction_tone: 한국 대중 반응의 전체 분위기. supportive(응원), critical(비판), divided(찬반), amused(웃김/밈), neutral(담담). 실제 댓글이 없으면 뉴스 내용 기반으로 판단
- issue_tags: COMEBACK, CHART, AWARD, AGENCY, CONTRACT, CONTROVERSY, FANDOM, MILITARY, RELATIONSHIP, LEGAL, SOCIAL_MEDIA, PERFORMANCE, COLLABORATION, BRAND_DEAL, VARIETY_SHOW, WORLD_TOUR, DEBUT, DISBANDMENT, SOLO, OST 중 선택
- artist_tags: 뉴스에 언급된 실제 아티스트/소속사 이름
- safety_flag: 혐오/검증안된루머/사생활침해면 "blocked", 아니면 "safe"
- importance_score: 1~10 (10이 가장 핫한 이슈)
- 절대로 존재하지 않는 댓글이나 반응을 만들어내지 마라. 실제 데이터만 분석해라.
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
    required List<String> issueTags,
    required List<String> artistTags,
    required List<Map<String, String>> sources,
  }) async {
    // 실제 댓글을 소스/좋아요와 함께 전달
    final hasComments = realComments.isNotEmpty;
    final reactionsStr = hasComments
        ? realComments.take(5).map((c) =>
            '- "${c['text']}" (${c['likes']} likes, from ${c['source']})').join('\n')
        : 'No real user comments were collected for this article.';

    final sourcesStr = sources
        .map((s) => '- ${s['title']}: ${s['url']}')
        .join('\n');

    _geminiCallCount++;

    final prompt = '''
You are KOK's content writer — you translate Korean K-pop news for international fans.

Voice: witty, sharp, insider-tone. Like a bilingual Korean friend explaining what's going on.

---

[INPUT]
Korean Summary: $koreanSummary
Reaction Tone: $reactionTone
${hasComments ? 'REAL collected comments (translate these faithfully):' : 'No real comments available for this article.'}
$reactionsStr
Tags: ${issueTags.join(', ')}
Artists: ${artistTags.join(', ')}
Sources:
$sourcesStr

---

[OUTPUT — JSON]
{
  "issue_title_en": "Sharp headline, max 100 chars",
  "issue_title_es": "Spanish version",
  "what_happened_en": "What happened, max 350 chars",
  "what_happened_es": "Spanish version",
  "why_it_matters_en": "Why Koreans care, max 350 chars",
  "why_it_matters_es": "Spanish version",
  "korean_reaction_summary_en": "Summary of Korean public reaction based on collected data, max 450 chars",
  "korean_reaction_summary_es": "Spanish version",
  ${hasComments ? '"top_reactions": [\n    {"content_en": "Faithful translation of the real comment above", "content_es": "Spanish", "likes": EXACT_NUMBER_FROM_INPUT, "source": "EXACT_SOURCE_FROM_INPUT"}\n  ],' : '"top_reactions": [],'}
  "context_for_fans_en": "Cultural context international fans might miss, max 400 chars",
  "context_for_fans_es": "Spanish version",
  "sentiment": "$reactionTone"
}

---

CRITICAL RULES:
1. top_reactions: ONLY translate the REAL comments provided above. Use the EXACT likes count and source from the input. DO NOT invent comments, likes, or sources.
2. If no real comments were provided, return an EMPTY top_reactions array [].
3. Do NOT fabricate any source names (no "Twitter", "TheQoo", etc. unless they appear in the input).
4. Title: catchy but not clickbait.
5. context_for_fans: explain Korean cultural nuances fans might miss.
6. Spanish: natural Latin American Gen-Z tone, not Google Translate.
''';

    final result = await _ai.generateCardJson(prompt, maxTokens: 2048);

    final titleEn = result['issue_title_en'] as String? ?? '';
    final bodyEn = result['what_happened_en'] as String? ?? '';
    final outputSafety = _safety.checkTranslatedContent('$titleEn $bodyEn');
    if (outputSafety.level == SafetyLevel.blocked) {
      return {'blocked': true, 'reason': outputSafety.reason};
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

        final card = await generateCard(
          koreanSummary: summary['issue_summary_ko'] as String? ?? '',
          reactionTone: summary['reaction_tone'] as String? ?? 'neutral',
          realComments: realCommentData,
          issueTags: List<String>.from(summary['issue_tags'] ?? []),
          artistTags: List<String>.from(summary['artist_tags'] ?? []),
          sources: sources,
        );

        if (card['blocked'] == true) {
          debugPrint('[KOK Pipeline] Card blocked: ${card['reason']}');
          continue;
        }

        card['issue_tags'] = summary['issue_tags'];
        card['artist_tags'] = summary['artist_tags'];
        card['reaction_sample_size'] = realCommentData.length;
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
