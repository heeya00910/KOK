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

  int scoreImportance(Map<String, dynamic> cluster) {
    final items = cluster['items'] as List;
    int score = items.length * 10;

    final rep = cluster['representative'] as Map<String, dynamic>;
    final title = (rep['title'] as String? ?? '').toLowerCase();

    const highValueKo = ['컴백', '빌보드', '신기록', '월드투어', '수상', '데뷔', '1위', '차트'];
    const mediumValueKo = ['논란', '소송', '열애', '입대', '계약', '탈퇴', '해체', '폭로', '사과'];
    const highValueEn = ['comeback', 'billboard', 'record', 'world tour', 'award', 'debut', '#1', 'chart'];
    const mediumValueEn = ['controversy', 'lawsuit', 'dating', 'military', 'contract', 'disband'];

    for (final kw in highValueKo) {
      if (title.contains(kw)) score += 20;
    }
    for (final kw in mediumValueKo) {
      if (title.contains(kw)) score += 15;
    }
    for (final kw in highValueEn) {
      if (title.contains(kw)) score += 20;
    }
    for (final kw in mediumValueEn) {
      if (title.contains(kw)) score += 15;
    }

    final hasComments = (rep['comments'] as List?)?.isNotEmpty ?? false;
    if (hasComments) score += 25;

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

    final commentsSection = sanitizedComments.isEmpty
        ? 'No user comments available. Analyze based on title and summary only. For key_reactions, generate 2-3 plausible Korean public reactions based on the tone and topic.'
        : 'Top reactions (${sanitizedComments.length}):\n${sanitizedComments.join('\n')}';

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
  "key_reactions": [
    {"text": "실제 한국 대중 반응을 대표하는 댓글 (한국어)", "tone": "supportive", "likes": 1234}
  ],
  "safety_flag": "safe",
  "importance_score": 7
}

규칙:
- is_relevant: K-pop 아이돌, 소속사, 업계 뉴스면 true
- issue_summary_ko: "왜 이게 화제인지"를 담아야 함. 단순 사실 나열 X, 맥락과 의미 포함 O
- reaction_tone: 한국 대중 반응의 전체 분위기. supportive(응원), critical(비판), divided(찬반), amused(웃김/밈), neutral(담담)
- key_reactions: 2~3개. 서로 다른 시각을 보여주는 반응들. 실제 댓글이 없으면 한국 커뮤니티(더쿠/인스티즈/네이버) 분위기에 맞는 현실적인 반응 생성. "ㅋㅋㅋ", "ㄷㄷ", "와..." 같은 한국식 표현 사용 OK
- issue_tags: COMEBACK, CHART, AWARD, AGENCY, CONTRACT, CONTROVERSY, FANDOM, MILITARY, RELATIONSHIP, LEGAL, SOCIAL_MEDIA, PERFORMANCE, COLLABORATION, BRAND_DEAL, VARIETY_SHOW, WORLD_TOUR, DEBUT, DISBANDMENT, SOLO, OST 중 선택
- artist_tags: 뉴스에 언급된 실제 아티스트/소속사 이름
- safety_flag: 혐오/검증안된루머/사생활침해면 "blocked", 아니면 "safe"
- importance_score: 1~10 (10이 가장 핫한 이슈)
''', maxTokens: 1024);

    _summaryCache[contentHash] = result;
    return result;
  }

  // ── Step 5: Gemini — generate EN/ES cards ──

  Future<Map<String, dynamic>> geminiGenerateCard({
    required String koreanSummary,
    required String reactionTone,
    required List<Map<String, dynamic>> keyReactions,
    required List<String> issueTags,
    required List<String> artistTags,
    required List<Map<String, String>> sources,
  }) async {
    final reactionsStr = keyReactions
        .take(5)
        .map((r) => '- "${r['text']}" (${r['tone']}, ${r['likes']} likes)')
        .join('\n');

    final sourcesStr = sources
        .map((s) => '- ${s['title']}: ${s['url']}')
        .join('\n');

    _geminiCallCount++;
    debugPrint('[KOK Pipeline] Gemini call #$_geminiCallCount: generating card');

    final result = await _ai.callGeminiJson('''
You are KOK's content writer — you translate the Korean K-pop conversation for international fans.

Your voice: witty, sharp, insider-tone. Like a bilingual Korean friend explaining what's REALLY going on.
NOT: robotic news reporter. NOT: clickbait youtuber.

---

[INPUT — Korean analysis]
Korean Summary: $koreanSummary
Reaction Tone: $reactionTone
Key Korean Reactions:
$reactionsStr
Tags: ${issueTags.join(', ')}
Artists: ${artistTags.join(', ')}
Sources:
$sourcesStr

---

[OUTPUT — JSON, BOTH English AND Spanish]
{
  "issue_title_en": "Headline that hooks. Sharp, clear, max 100 chars. No ALL CAPS. No clickbait.",
  "issue_title_es": "Same energy in Spanish",
  "what_happened_en": "The facts — what actually happened. Clear, concise, max 350 chars.",
  "what_happened_es": "Spanish version",
  "why_it_matters_en": "Why Koreans care about this. Industry/cultural significance. Max 350 chars.",
  "why_it_matters_es": "Spanish version",
  "korean_reaction_summary_en": "The real vibe — how Korean netizens/public are reacting. Show the spectrum of opinions. Capture the tone (sarcasm, humor, outrage, support). Max 450 chars.",
  "korean_reaction_summary_es": "Spanish version",
  "top_reactions": [
    {"content_en": "Translated Korean reaction (keep the flavor — sarcasm, wit, slang)", "content_es": "Spanish", "likes": 12345, "source": "Naver"},
    {"content_en": "A different perspective/reaction", "content_es": "Spanish", "likes": 5678, "source": "YouTube"}
  ],
  "context_for_fans_en": "What international fans might not know — cultural context, industry norms, why Koreans react this way. Max 400 chars.",
  "context_for_fans_es": "Spanish version",
  "sentiment": "$reactionTone"
}

---

QUALITY RULES:
1. TITLE: Would you actually tap on this? If not, rewrite it.
2. REACTIONS: Preserve the original Korean flavor. "Koreans are saying..." is boring. Instead: capture the actual wit, sarcasm, or raw emotion.
3. CONTEXT: This is KOK's killer feature. Explain things like military service culture, music show wins meaning, Melon chart politics, agency reputation, trainee systems — things only someone IN Korea would know.
4. SPANISH: Not Google Translate. Natural Latin American / Spanish Gen-Z tone.
5. top_reactions: 2-3 entries showing DIFFERENT viewpoints (fans vs general public, positive vs critical).
6. NO: generic filler, "fans are excited", "this is big news". Be SPECIFIC.
''', maxTokens: 2048);

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

        final card = await geminiGenerateCard(
          koreanSummary: summary['issue_summary_ko'] as String? ?? '',
          reactionTone: summary['reaction_tone'] as String? ?? 'neutral',
          keyReactions: List<Map<String, dynamic>>.from(summary['key_reactions'] ?? []),
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
        card['reaction_sample_size'] = comments.length > 0 ? comments.length * 100 : 1000;
        card['original_sources'] = sources;
        card['safety_level'] = summary['safety_flag'];

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
