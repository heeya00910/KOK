import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Collects K-pop news candidates from external APIs.
/// Sources:
///   1. Naver News Search API — Korean news articles
///   2. YouTube Data API — Official MV/video comments
class SourceCollector {
  static final SourceCollector _instance = SourceCollector._();
  factory SourceCollector() => _instance;
  SourceCollector._();

  String get _naverClientId => dotenv.env['NAVER_CLIENT_ID'] ?? '';
  String get _naverClientSecret => dotenv.env['NAVER_CLIENT_SECRET'] ?? '';
  String get _youtubeApiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';

  /// K-pop related search queries rotated per run to stay within rate limits
  static const _kpopQueries = [
    '아이돌 컴백',
    'K-pop 뉴스',
    '아이돌 논란',
    '아이돌 빌보드',
    '케이팝 팬덤',
    '아이돌 콘서트',
    '엔터 소속사',
    '아이돌 음원',
  ];

  int _queryRotation = 0;

  // ── Naver News Search API ──

  Future<List<Map<String, dynamic>>> collectFromNaverNews({
    int displayCount = 20,
  }) async {
    if (_naverClientId.isEmpty || _naverClientSecret.isEmpty) {
      return [];
    }

    final query = _kpopQueries[_queryRotation % _kpopQueries.length];
    _queryRotation++;

    try {
      final url = Uri.parse(
        'https://openapi.naver.com/v1/search/news.json'
        '?query=${Uri.encodeComponent(query)}'
        '&display=$displayCount'
        '&sort=date'
        '&start=1',
      );

      final response = await http.get(url, headers: {
        'X-Naver-Client-Id': _naverClientId,
        'X-Naver-Client-Secret': _naverClientSecret,
      });

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final items = data['items'] as List? ?? [];

      return items.map((item) {
        final title = _stripHtml(item['title'] ?? '');
        final description = _stripHtml(item['description'] ?? '');
        return <String, dynamic>{
          'title': title,
          'snippet': description,
          'url': item['originallink'] ?? item['link'] ?? '',
          'source': 'naver_news',
          'published_at': item['pubDate'] ?? '',
          'comments': <String>[],
        };
      }).where((item) {
        final title = item['title'] as String;
        return title.length >= 10;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── YouTube Data API ──

  Future<List<Map<String, dynamic>>> collectFromYouTube({
    int maxResults = 10,
  }) async {
    if (_youtubeApiKey.isEmpty) return [];

    try {
      final videos = await _searchYouTubeVideos(maxResults: maxResults);
      final results = <Map<String, dynamic>>[];

      for (final video in videos.take(5)) {
        final videoId = video['videoId'] as String;
        final comments = await _fetchYouTubeComments(videoId, maxResults: 15);

        results.add({
          'title': video['title'] ?? '',
          'snippet': video['description'] ?? '',
          'url': 'https://www.youtube.com/watch?v=$videoId',
          'source': 'youtube',
          'published_at': video['publishedAt'] ?? '',
          'comments': comments,
          'channel': video['channelTitle'] ?? '',
        });
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchYouTubeVideos({
    int maxResults = 10,
  }) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet'
      '&q=${Uri.encodeComponent("K-pop 뉴스 아이돌")}'
      '&type=video'
      '&order=date'
      '&regionCode=KR'
      '&relevanceLanguage=ko'
      '&maxResults=$maxResults'
      '&publishedAfter=${_twentyFourHoursAgo()}'
      '&key=$_youtubeApiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final items = data['items'] as List? ?? [];

    return items.map((item) {
      final snippet = item['snippet'] ?? {};
      return <String, dynamic>{
        'videoId': item['id']?['videoId'] ?? '',
        'title': snippet['title'] ?? '',
        'description': snippet['description'] ?? '',
        'channelTitle': snippet['channelTitle'] ?? '',
        'publishedAt': snippet['publishedAt'] ?? '',
      };
    }).where((v) => (v['videoId'] as String).isNotEmpty).toList();
  }

  Future<List<String>> _fetchYouTubeComments(
    String videoId, {
    int maxResults = 15,
  }) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/commentThreads'
      '?part=snippet'
      '&videoId=$videoId'
      '&order=relevance'
      '&maxResults=$maxResults'
      '&textFormat=plainText'
      '&key=$_youtubeApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final items = data['items'] as List? ?? [];

      return items.map((item) {
        final comment = item['snippet']?['topLevelComment']?['snippet'];
        final text = comment?['textDisplay'] ?? '';
        return text as String;
      }).where((t) => t.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  String _twentyFourHoursAgo() {
    final dt = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    return dt.toIso8601String();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&apos;', "'")
        .trim();
  }
}
