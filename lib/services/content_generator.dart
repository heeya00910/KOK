import 'ai_service.dart';

/// High-level content generation using Groq + Gemini pipeline.
/// This is a convenience wrapper; the full pipeline is in content_pipeline.dart.
class ContentGenerator {
  static final ContentGenerator _instance = ContentGenerator._();
  factory ContentGenerator() => _instance;
  ContentGenerator._();

  final _ai = AiService();

  Future<String> translateText(String text, {required String from, required String to}) async {
    final prompt = 'Translate the following $from text to $to. Return ONLY the translation.\n\n$text';
    return await _ai.callGemini(prompt, maxTokens: 512);
  }

  Future<Map<String, dynamic>> summarizeKoreanContent({
    required String title,
    required String snippet,
    required List<String> comments,
  }) async {
    final commentsStr = comments.take(15).join('\n');
    return await _ai.callGroqJson('''
Summarize this Korean K-pop news and classify the reactions.

Title: $title
Snippet: $snippet
Comments:
$commentsStr

Output JSON:
{
  "summary": "2-3 sentence summary",
  "reaction_tone": "positive/negative/mixed/neutral",
  "key_points": ["point1", "point2"],
  "is_relevant": true/false
}
''', maxTokens: 512);
  }
}
