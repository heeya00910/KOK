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
Analyze this Korean K-pop news item.

Title: ${title.length > 120 ? '${title.substring(0, 120)}...' : title}
Summary: ${snippet.length > 400 ? '${snippet.substring(0, 400)}...' : snippet}

$commentsSection

Output JSON:
{
  "is_relevant": true,
  "issue_summary_ko": "2-3 sentence Korean summary of the core issue",
  "reaction_tone": "positive/negative/mixed/neutral",
  "issue_tags": ["COMEBACK","CONTROVERSY"],
  "artist_tags": ["BTS","aespa"],
  "key_reactions": [
    {"text": "representative Korean comment or plausible reaction", "tone": "positive", "likes": 1234}
  ],
  "safety_flag": "safe",
  "importance_score": 7
}

Rules:
- Set is_relevant to true if this is about K-pop idols, agencies, or the K-pop industry
- issue_tags MUST be from: COMEBACK, CHART, AWARD, AGENCY, CONTRACT, CONTROVERSY, FANDOM, MILITARY, RELATIONSHIP, LEGAL, SOCIAL_MEDIA, PERFORMANCE, COLLABORATION, BRAND_DEAL, VARIETY_SHOW, WORLD_TOUR, DEBUT, DISBANDMENT, SOLO, OST
- key_reactions: provide 2-3 entries. If no real comments given, create realistic Korean public reactions
- artist_tags: extract actual artist/agency names mentioned
- safety_flag: "safe" unless content contains hate speech, unverified rumors, or privacy violations
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
You are KOK's content writer. Create a K-pop news card for international fans.
Write in an engaging, catchy, Gen-Z-friendly tone. Be authentic about Korean opinions.

Korean Issue Summary: $koreanSummary
Overall Reaction Tone: $reactionTone
Key Korean Reactions:
$reactionsStr
Issue Tags: ${issueTags.join(', ')}
Artists/Agencies: ${artistTags.join(', ')}
Original Sources:
$sourcesStr

Generate a KOK card in BOTH English and Spanish. Output JSON:
{
  "issue_title_en": "Catchy English headline (max 120 chars)",
  "issue_title_es": "Spanish headline (max 120 chars)",
  "what_happened_en": "Factual summary (max 400 chars)",
  "what_happened_es": "Same in Spanish",
  "why_it_matters_en": "Why this matters in Korea (max 400 chars)",
  "why_it_matters_es": "Same in Spanish",
  "korean_reaction_summary_en": "Summary of Korean reactions (max 500 chars)",
  "korean_reaction_summary_es": "Same in Spanish",
  "top_reactions": [
    {"content_en": "Translated reaction", "content_es": "Spanish", "likes": 12345, "source": "Naver"}
  ],
  "context_for_fans_en": "Cultural context for international fans (max 500 chars)",
  "context_for_fans_es": "Same in Spanish",
  "sentiment": "$reactionTone"
}

Rules:
- Title: catchy but NOT clickbait
- Show REAL diversity of Korean opinions
- top_reactions: 2-3 entries with different viewpoints
- context_for_fans: explain Korean cultural nuances fans might miss
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
