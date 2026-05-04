import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'ai_service.dart';
import 'content_safety.dart';

/// Full content pipeline: collect → filter → summarize → generate cards → store
class ContentPipeline {
  static final ContentPipeline _instance = ContentPipeline._();
  factory ContentPipeline() => _instance;
  ContentPipeline._();

  final _ai = AiService();
  final _safety = ContentSafetyFilter();

  // Processed URL hashes to avoid reprocessing
  final Set<String> _processedHashes = {};
  // Cache: groq summary hash → result
  final Map<String, Map<String, dynamic>> _summaryCache = {};

  // ── Step 1: Pre-filter without LLM ──

  List<Map<String, dynamic>> preFilter(List<Map<String, dynamic>> candidates) {
    final seen = <String>{};
    final filtered = <Map<String, dynamic>>[];

    for (final item in candidates) {
      final url = item['url'] as String? ?? '';
      final urlHash = _hash(url);

      // Skip already processed URLs
      if (_processedHashes.contains(urlHash)) continue;
      // Skip duplicate URLs in this batch
      if (seen.contains(urlHash)) continue;
      seen.add(urlHash);

      // Must have title
      final title = item['title'] as String? ?? '';
      if (title.length < 5) continue;

      filtered.add(item);
    }

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

    final result = await _ai.callGroqJson('''
Group these K-pop news titles into issue clusters. Titles about the same event/topic go together.

$titlesStr

Output JSON:
{"clusters": [[0,3,5], [1,2], [4]]}

Each array contains indices of titles that belong to the same issue.
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

    return clusters ?? items.map((i) => {'items': [i], 'representative': i}).toList();
  }

  // ── Step 3: Score importance ──

  int scoreImportance(Map<String, dynamic> cluster) {
    final items = cluster['items'] as List;
    int score = 0;

    // More sources covering = more important
    score += items.length * 10;

    final rep = cluster['representative'] as Map<String, dynamic>;
    final title = (rep['title'] as String? ?? '').toLowerCase();

    // High-value keywords
    const highValue = ['comeback', 'billboard', 'record', 'world tour', 'award', 'debut'];
    const mediumValue = ['controversy', 'lawsuit', 'dating', 'military', 'contract'];

    for (final kw in highValue) {
      if (title.contains(kw)) score += 20;
    }
    for (final kw in mediumValue) {
      if (title.contains(kw)) score += 15;
    }

    return score;
  }

  // ── Step 4: Groq — Korean summary + reaction classification ──

  Future<Map<String, dynamic>> groqSummarize({
    required String title,
    required String snippet,
    required List<String> comments,
  }) async {
    final contentHash = _hash('$title$snippet');
    if (_summaryCache.containsKey(contentHash)) {
      return _summaryCache[contentHash]!;
    }

    // Safety check first
    final safety = _safety.checkKoreanContent(title, snippet);
    if (safety.level == SafetyLevel.blocked) {
      return {'blocked': true, 'reason': safety.reason};
    }

    final sanitizedComments = comments
        .take(15)
        .map((c) => c.length > 160 ? '${c.substring(0, 160)}...' : c)
        .map((c) => _safety.sanitizeComment(c))
        .toList();

    final result = await _ai.callGroqJson('''
Analyze this Korean K-pop news item.

Title (max 120 chars): ${title.length > 120 ? '${title.substring(0, 120)}...' : title}
Summary (max 400 chars): ${snippet.length > 400 ? '${snippet.substring(0, 400)}...' : snippet}

Top reactions (${sanitizedComments.length}):
${sanitizedComments.join('\n')}

Output JSON:
{
  "is_relevant": true/false,
  "issue_summary_ko": "2-3 sentence Korean summary of the core issue",
  "reaction_tone": "positive/negative/mixed/neutral",
  "issue_tags": ["COMEBACK","CONTROVERSY",...],
  "artist_tags": ["BTS","aespa",...],
  "key_reactions": [
    {"text": "representative Korean comment", "tone": "positive/negative/neutral", "likes": 1234}
  ],
  "safety_flag": "safe/review_needed/blocked",
  "safety_reason": "",
  "importance_score": 1-10,
  "is_duplicate_of": null
}

Only include issue_tags from: COMEBACK, CHART, AWARD, AGENCY, CONTRACT, CONTROVERSY, FANDOM, MILITARY, RELATIONSHIP, LEGAL, SOCIAL_MEDIA, PERFORMANCE, COLLABORATION, BRAND_DEAL, VARIETY_SHOW, WORLD_TOUR, DEBUT, DISBANDMENT, SOLO, OST
Be strict about safety. Block unverified rumors, privacy violations, minor sexualization, hate speech.
''', maxTokens: 1024);

    _summaryCache[contentHash] = result;
    return result;
  }

  // ── Step 5: Gemini — Generate EN/ES KOK cards ──

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
  "what_happened_en": "Factual summary of what happened (max 400 chars)",
  "what_happened_es": "Same in Spanish",
  "why_it_matters_en": "Why this is a big deal in Korea (max 400 chars)",
  "why_it_matters_es": "Same in Spanish",
  "korean_reaction_summary_en": "Summary of Korean public reaction with sentiment breakdown (max 500 chars)",
  "korean_reaction_summary_es": "Same in Spanish",
  "top_reactions": [
    {
      "content_en": "Translated Korean reaction in quotes",
      "content_es": "Same in Spanish",
      "likes": 12345,
      "source": "Naver/YouTube/TheQoo"
    }
  ],
  "context_for_fans_en": "Background context for international fans (max 500 chars)",
  "context_for_fans_es": "Same in Spanish",
  "sentiment": "$reactionTone"
}

IMPORTANT:
- Make the title catchy and click-worthy but NOT clickbait
- Show the REAL diversity of Korean opinions, not sanitized versions
- top_reactions should be 2-3 representative comments showing different viewpoints
- context_for_fans should explain cultural nuances international fans might miss
- Keep it authentic: if Koreans are angry, say so; if divided, show both sides
''', maxTokens: 2048);

    // Final safety check on generated content
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
    // 1. Pre-filter (no LLM)
    final filtered = preFilter(rawCandidates);
    if (filtered.isEmpty) return [];

    // 2. Cluster similar issues
    final clusters = await clusterIssues(filtered);

    // 3. Score and sort by importance
    final scored = clusters.map((c) => {
      ...c,
      'score': scoreImportance(c),
    }).toList()
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    // 4. Process top issues only (token budget)
    final topIssues = scored.take(5).toList();
    final cards = <Map<String, dynamic>>[];

    for (final cluster in topIssues) {
      try {
        final rep = cluster['representative'] as Map<String, dynamic>;
        final title = rep['title'] as String? ?? '';
        final snippet = rep['snippet'] as String? ?? '';
        final comments = List<String>.from(rep['comments'] ?? []);

        // 5. Groq: summarize + classify
        final summary = await groqSummarize(
          title: title,
          snippet: snippet,
          comments: comments,
        );

        if (summary['blocked'] == true) continue;
        if (summary['is_relevant'] != true) continue;
        if (summary['safety_flag'] == 'blocked') continue;

        // 6. Gemini: generate card
        final items = cluster['items'] as List;
        final sources = items
            .map((i) => {
                  'title': (i as Map<String, dynamic>)['title']?.toString() ?? '',
                  'url': i['url']?.toString() ?? '',
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

        if (card['blocked'] == true) continue;

        card['issue_tags'] = summary['issue_tags'];
        card['artist_tags'] = summary['artist_tags'];
        card['reaction_sample_size'] = comments.length;
        card['original_sources'] = sources;
        card['safety_level'] = summary['safety_flag'];

        cards.add(card);

        // Mark URLs as processed
        for (final item in items) {
          final url = (item as Map<String, dynamic>)['url'] as String? ?? '';
          _processedHashes.add(_hash(url));
        }
      } catch (e) {
        // Skip failed items, don't crash the pipeline
        continue;
      }
    }

    return cards;
  }

  String _hash(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  void clearCache() {
    _summaryCache.clear();
  }
}
