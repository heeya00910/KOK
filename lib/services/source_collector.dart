import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SourceCollector {
  static final SourceCollector _instance = SourceCollector._();
  factory SourceCollector() => _instance;
  SourceCollector._();

  String get _naverClientId => dotenv.env['NAVER_CLIENT_ID'] ?? '';
  String get _naverClientSecret => dotenv.env['NAVER_CLIENT_SECRET'] ?? '';
  String get _youtubeApiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';

  static const _naverNewsQueries = [
    '아이돌 컴백 2025',
    'K-pop 뉴스',
    '아이돌 논란',
    '아이돌 빌보드',
    '케이팝 팬덤 반응',
    '아이돌 콘서트 투어',
    '엔터 소속사 뉴스',
    '아이돌 음원 차트',
    '케이팝 해외반응',
    '아이돌 컴백 무대',
  ];

  static const _naverBlogQueries = [
    '케이팝 여론 반응',
    '아이돌 뉴스 정리',
    '한국 반응 아이돌',
  ];

  static const _youtubeQueries = [
    'K-pop 뉴스 아이돌',
    '케이팝 컴백 리액션',
    '아이돌 논란 정리',
    '아이돌 여론 반응',
  ];

  int _naverRotation = 0;
  int _youtubeRotation = 0;

  // ── Naver News Search ──

  Future<List<Map<String, dynamic>>> collectFromNaverNews() async {
    if (_naverClientId.isEmpty || _naverClientSecret.isEmpty) {
      debugPrint('[KOK Source] Naver API keys missing');
      return [];
    }

    final results = <Map<String, dynamic>>[];

    final queriesToRun = [
      _naverNewsQueries[_naverRotation % _naverNewsQueries.length],
      _naverNewsQueries[(_naverRotation + 1) % _naverNewsQueries.length],
    ];
    _naverRotation += 2;

    for (final query in queriesToRun) {
      try {
        final items = await _searchNaverNews(query, display: 15);
        results.addAll(items);
        debugPrint('[KOK Source] Naver "$query": ${items.length} items');
      } catch (e) {
        debugPrint('[KOK Source] Naver "$query" failed: $e');
      }
    }

    final blogQuery = _naverBlogQueries[_naverRotation % _naverBlogQueries.length];
    try {
      final blogItems = await _searchNaverBlog(blogQuery, display: 10);
      results.addAll(blogItems);
      debugPrint('[KOK Source] Naver Blog "$blogQuery": ${blogItems.length} items');
    } catch (e) {
      debugPrint('[KOK Source] Naver Blog failed: $e');
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> _searchNaverNews(String query, {int display = 15}) async {
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/news.json'
      '?query=${Uri.encodeComponent(query)}'
      '&display=$display'
      '&sort=date'
      '&start=1',
    );

    final response = await http.get(url, headers: {
      'X-Naver-Client-Id': _naverClientId,
      'X-Naver-Client-Secret': _naverClientSecret,
    });

    if (response.statusCode != 200) {
      debugPrint('[KOK Source] Naver News API ${response.statusCode}: ${response.body.substring(0, 200)}');
      return [];
    }

    final data = jsonDecode(response.body);
    final items = data['items'] as List? ?? [];

    return items.map((item) {
      final title = _stripHtml(item['title'] ?? '');
      final desc = _stripHtml(item['description'] ?? '');
      return <String, dynamic>{
        'title': title,
        'snippet': desc,
        'url': item['originallink'] ?? item['link'] ?? '',
        'source': 'naver_news',
        'published_at': item['pubDate'] ?? '',
        'comments': <String>[],
      };
    }).where((item) => (item['title'] as String).length >= 10).toList();
  }

  Future<List<Map<String, dynamic>>> _searchNaverBlog(String query, {int display = 10}) async {
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/blog.json'
      '?query=${Uri.encodeComponent(query)}'
      '&display=$display'
      '&sort=date',
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
      final desc = _stripHtml(item['description'] ?? '');
      return <String, dynamic>{
        'title': title,
        'snippet': desc,
        'url': item['link'] ?? '',
        'source': 'naver_blog',
        'published_at': item['postdate'] ?? '',
        'comments': <String>[],
      };
    }).where((item) => (item['title'] as String).length >= 10).toList();
  }

  // ── YouTube Data API ──

  Future<List<Map<String, dynamic>>> collectFromYouTube() async {
    if (_youtubeApiKey.isEmpty) {
      debugPrint('[KOK Source] YouTube API key missing');
      return [];
    }

    final query = _youtubeQueries[_youtubeRotation % _youtubeQueries.length];
    _youtubeRotation++;

    try {
      final videos = await _searchYouTubeVideos(query: query, maxResults: 8);
      debugPrint('[KOK Source] YouTube "$query": ${videos.length} videos');
      final results = <Map<String, dynamic>>[];

      for (final video in videos.take(5)) {
        final videoId = video['videoId'] as String;
        List<String> comments = [];
        try {
          comments = await _fetchYouTubeComments(videoId, maxResults: 20);
        } catch (e) {
          debugPrint('[KOK Source] YouTube comments for $videoId failed: $e');
        }

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
    } catch (e) {
      debugPrint('[KOK Source] YouTube search failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchYouTubeVideos({
    required String query,
    int maxResults = 8,
  }) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet'
      '&q=${Uri.encodeComponent(query)}'
      '&type=video'
      '&order=date'
      '&regionCode=KR'
      '&relevanceLanguage=ko'
      '&maxResults=$maxResults'
      '&publishedAfter=${_hoursAgo(48)}'
      '&key=$_youtubeApiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      debugPrint('[KOK Source] YouTube Search API ${response.statusCode}');
      return [];
    }

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

  Future<List<String>> _fetchYouTubeComments(String videoId, {int maxResults = 20}) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/commentThreads'
      '?part=snippet'
      '&videoId=$videoId'
      '&order=relevance'
      '&maxResults=$maxResults'
      '&textFormat=plainText'
      '&key=$_youtubeApiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final items = data['items'] as List? ?? [];

    return items.map((item) {
      final comment = item['snippet']?['topLevelComment']?['snippet'];
      return (comment?['textDisplay'] ?? '') as String;
    }).where((t) => t.isNotEmpty).toList();
  }

  String _hoursAgo(int hours) {
    return DateTime.now().toUtc().subtract(Duration(hours: hours)).toIso8601String();
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
