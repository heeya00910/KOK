import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static final AiService _instance = AiService._();
  factory AiService() => _instance;
  AiService._();

  DateTime? _geminiCooldown;
  DateTime? _groqCooldown;
  DateTime? _cerebrasCooldown;

  String get _geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _groqKey => dotenv.env['GROQ_API_KEY'] ?? '';
  String get _cerebrasKey => dotenv.env['CEREBRAS_API_KEY'] ?? '';

  void resetCooldowns() {
    _geminiCooldown = null;
    _groqCooldown = null;
    _cerebrasCooldown = null;
  }

  // ═══════════════════════════════════════════
  //  Groq — 분석/요약 주력
  // ═══════════════════════════════════════════

  Future<String> callGroq(String prompt, {int maxTokens = 1024, bool jsonMode = false}) async {
    _checkCooldown(_groqCooldown, 'Groq');

    final body = <String, dynamic>{
      'model': 'llama-3.3-70b-versatile',
      'messages': [
        {'role': 'system', 'content': 'You are a K-pop news analyst. Be concise and factual. Respond in the exact format requested.'},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.3,
      'max_tokens': maxTokens,
    };
    if (jsonMode) {
      body['response_format'] = {'type': 'json_object'};
    }

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 429) {
      _groqCooldown = DateTime.now().add(const Duration(seconds: 30));
      throw RateLimitException('Groq rate limited');
    }
    if (response.statusCode != 200) {
      throw ApiException('Groq ${response.statusCode}: ${_safeSub(response.body)}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<Map<String, dynamic>> callGroqJson(String prompt, {int maxTokens = 1024}) async {
    final raw = await callGroq(prompt, maxTokens: maxTokens, jsonMode: true);
    return _parseJson(raw);
  }

  // ═══════════════════════════════════════════
  //  Cerebras — 일일 한도 무제한, Groq와 같은 모델
  // ═══════════════════════════════════════════

  Future<String> callCerebras(String prompt, {int maxTokens = 2048, bool jsonMode = false}) async {
    _checkCooldown(_cerebrasCooldown, 'Cerebras');

    final body = <String, dynamic>{
      'model': 'llama3.1-8b',
      'messages': [
        {'role': 'system', 'content': 'You are a K-pop content writer. Be creative, witty, and culturally accurate. Respond in the exact format requested.'},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.7,
      'max_tokens': maxTokens,
    };
    if (jsonMode) {
      body['response_format'] = {'type': 'json_object'};
    }

    final response = await http.post(
      Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_cerebrasKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 429) {
      _cerebrasCooldown = DateTime.now().add(const Duration(seconds: 20));
      throw RateLimitException('Cerebras rate limited');
    }
    if (response.statusCode != 200) {
      throw ApiException('Cerebras ${response.statusCode}: ${_safeSub(response.body)}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<Map<String, dynamic>> callCerebrasJson(String prompt, {int maxTokens = 2048}) async {
    final raw = await callCerebras(prompt, maxTokens: maxTokens, jsonMode: true);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════
  //  Gemini — 다국어 번역 강점
  // ═══════════════════════════════════════════

  Future<String> callGemini(String prompt, {int maxTokens = 2048}) async {
    _checkCooldown(_geminiCooldown, 'Gemini');

    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        debugPrint('[KOK AI] Gemini retry after 8s');
        await Future.delayed(const Duration(seconds: 8));
      }

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$_geminiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': maxTokens},
        }),
      );

      if (response.statusCode == 429) {
        debugPrint('[KOK AI] Gemini 429 on attempt ${attempt + 1}');
        if (attempt == 1) {
          _geminiCooldown = DateTime.now().add(const Duration(seconds: 30));
          throw RateLimitException('Gemini rate limited');
        }
        continue;
      }

      if (response.statusCode != 200) {
        throw ApiException('Gemini ${response.statusCode}: ${_safeSub(response.body)}');
      }

      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }

    throw ApiException('Gemini: max retries exceeded');
  }

  Future<Map<String, dynamic>> callGeminiJson(String prompt, {int maxTokens = 2048}) async {
    final raw = await callGemini('$prompt\n\nRespond ONLY with valid JSON, no markdown fences.', maxTokens: maxTokens);
    return _parseJson(raw);
  }

  // ═══════════════════════════════════════════
  //  통합 카드 생성: Gemini → Cerebras → Groq
  // ═══════════════════════════════════════════

  Future<Map<String, dynamic>> generateCardJson(String prompt, {int maxTokens = 2048}) async {
    // 1차: Gemini (다국어 번역 최강)
    try {
      final result = await callGeminiJson(prompt, maxTokens: maxTokens);
      debugPrint('[KOK AI] Card by Gemini');
      return result;
    } on RateLimitException {
      debugPrint('[KOK AI] Gemini limited → Cerebras');
    } catch (e) {
      debugPrint('[KOK AI] Gemini failed → Cerebras');
    }

    // 2차: Cerebras (일일 한도 무제한)
    try {
      final result = await callCerebrasJson(prompt, maxTokens: maxTokens);
      debugPrint('[KOK AI] Card by Cerebras');
      return result;
    } on RateLimitException {
      debugPrint('[KOK AI] Cerebras limited → Groq');
    } catch (e) {
      debugPrint('[KOK AI] Cerebras failed: $e → Groq');
    }

    // 3차: Groq (최후 보루)
    final result = await callGroqJson(prompt, maxTokens: maxTokens);
    debugPrint('[KOK AI] Card by Groq (final fallback)');
    return result;
  }

  // ═══════════════════════════════════════════
  //  유틸
  // ═══════════════════════════════════════════

  void _checkCooldown(DateTime? cooldown, String name) {
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      throw RateLimitException('$name cooling down until $cooldown');
    }
  }

  Map<String, dynamic> _parseJson(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .trim();
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  String _safeSub(String s, [int len = 200]) =>
      s.length <= len ? s : s.substring(0, len);
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
