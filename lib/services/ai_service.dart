import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Low-level AI API caller with rate-limit handling
class AiService {
  static final AiService _instance = AiService._();
  factory AiService() => _instance;
  AiService._();

  DateTime? _geminiCooldown;
  DateTime? _groqCooldown;

  String get _geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _groqKey => dotenv.env['GROQ_API_KEY'] ?? '';

  // ── Groq: filtering, summarizing, classifying ──

  Future<String> callGroq(String prompt, {int maxTokens = 1024}) async {
    _checkCooldown(_groqCooldown, 'Groq');

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a K-pop news analyst. Be concise and factual. Respond in the exact format requested.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode == 429) {
      _groqCooldown = DateTime.now().add(const Duration(minutes: 2));
      throw RateLimitException('Groq rate limited');
    }
    if (response.statusCode != 200) {
      throw ApiException('Groq error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<Map<String, dynamic>> callGroqJson(String prompt, {int maxTokens = 1024}) async {
    final raw = await callGroq('$prompt\n\nRespond ONLY with valid JSON.', maxTokens: maxTokens);
    return _parseJson(raw);
  }

  // ── Gemini: card generation, translation, polishing ──

  Future<String> callGemini(String prompt, {int maxTokens = 2048}) async {
    _checkCooldown(_geminiCooldown, 'Gemini');

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': maxTokens,
        },
      }),
    );

    if (response.statusCode == 429) {
      _geminiCooldown = DateTime.now().add(const Duration(minutes: 2));
      throw RateLimitException('Gemini rate limited');
    }
    if (response.statusCode != 200) {
      throw ApiException('Gemini error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  Future<Map<String, dynamic>> callGeminiJson(String prompt, {int maxTokens = 2048}) async {
    final raw = await callGemini('$prompt\n\nRespond ONLY with valid JSON, no markdown fences.', maxTokens: maxTokens);
    return _parseJson(raw);
  }

  void _checkCooldown(DateTime? cooldown, String name) {
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      throw RateLimitException('$name is cooling down until $cooldown');
    }
  }

  Map<String, dynamic> _parseJson(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .trim();
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  @override
  String toString() => message;
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
