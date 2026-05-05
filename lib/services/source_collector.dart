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

  // 미국/중남미에서 인지도 높은 메이저 아이돌 + 소속사
  static const _majorArtists = [
    'BTS', '방탄소년단', 'BLACKPINK', '블랙핑크',
    'Stray Kids', '스트레이 키즈', 'SEVENTEEN', '세븐틴',
    'aespa', '에스파', 'NewJeans', '뉴진스',
    'ENHYPEN', '엔하이픈', 'TWICE', '트와이스',
    'IVE', '아이브', 'LE SSERAFIM', '르세라핌',
    'NCT', 'EXO', '엑소', 'Red Velvet', '레드벨벳',
    'ATEEZ', '에이티즈', 'TXT', '투모로우바이투게더',
    'ITZY', '잇지', 'NMIXX', '엔믹스',
    '(G)I-DLE', '여자아이들', 'TREASURE', '트레저',
    'Kep1er', '케플러', 'ILLIT', '아일릿',
    'BABYMONSTER', '베이비몬스터', 'RIIZE', '라이즈',
    'BOYNEXTDOOR', '보이넥스트도어', 'ZEROBASEONE', '제로베이스원',
    'KISS OF LIFE', 'TWS',
    'Jung Kook', '정국', 'Jimin', '지민', 'V', '뷔', 'SUGA', '슈가',
    'Lisa', '리사', 'Jennie', '제니', 'Rosé', '로제', 'Jisoo', '지수',
    'IU', '아이유', '임영웅',
  ];

  static const _majorAgencies = [
    'HYBE', '하이브', 'SM', 'YG', 'JYP', 'STARSHIP', '스타쉽',
    'PLEDIS', '플레디스', 'CUBE', '큐브', 'ADOR', '어도어',
    'KOZ', 'BIGHIT', '빅히트',
  ];

  // 뉴스 검색 쿼리: 메이저 아이돌 + 업계 핵심 이슈
  static const _naverQueries = [
    'BTS 뉴스', '블랙핑크 뉴스', '뉴진스 뉴스', '에스파 뉴스',
    '아이브 컴백', '르세라핌 뉴스', '세븐틴 뉴스', '스트레이키즈 뉴스',
    '케이팝 빌보드', '아이돌 컴백 2025',
    '하이브 뉴스', 'SM JYP YG 뉴스',
    '아이돌 논란', '케이팝 음원차트 1위',
    '아이돌 월드투어', '케이팝 시상식 수상',
    '엔하이픈 뉴스', 'TWICE 뉴스', 'NCT 뉴스',
    '정국 솔로', '제니 솔로', '로제 솔로', '아이유 뉴스',
  ];

  static const _youtubeQueries = [
    'BTS 뉴스 2025', '블랙핑크 뉴스', '뉴진스 컴백',
    '에스파 뉴스', '아이브 뉴스', '르세라핌 뉴스',
    '케이팝 논란 정리', '아이돌 빌보드 차트',
    '하이브 소식', '케이팝 핫이슈 정리',
  ];

  // 쓸모없는 콘텐츠 제외 패턴
  static final _trashPatterns = RegExp(
    r'(#shorts|#챌린지|챌린지|랜덤댄스|커버댄스|dance ?cover|random ?play|'
    r'먹방|ASMR|unboxing|언박싱|앨범깡|포카|팬싸|직캠|fancam|'
    r'reaction|리액션|#쇼츠|틱톡|tiktok)',
    caseSensitive: false,
  );

  int _naverIdx = 0;
  int _youtubeIdx = 0;

  // ── Naver News ──

  Future<List<Map<String, dynamic>>> collectFromNaverNews() async {
    if (_naverClientId.isEmpty || _naverClientSecret.isEmpty) {
      debugPrint('[KOK Source] Naver API keys missing');
      return [];
    }

    final results = <Map<String, dynamic>>[];

    // 3개 쿼리 로테이션
    for (int i = 0; i < 3; i++) {
      final query = _naverQueries[(_naverIdx + i) % _naverQueries.length];
      try {
        final items = await _searchNaverNews(query, display: 15);
        final filtered = _filterMajorOnly(items);
        results.addAll(filtered);
        debugPrint('[KOK Source] Naver "$query": ${items.length}→${filtered.length} (major only)');
      } catch (e) {
        debugPrint('[KOK Source] Naver "$query" failed: $e');
      }
    }
    _naverIdx += 3;

    return results;
  }

  Future<List<Map<String, dynamic>>> _searchNaverNews(String query, {int display = 15}) async {
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/news.json'
      '?query=${Uri.encodeComponent(query)}'
      '&display=$display'
      '&sort=date&start=1',
    );

    final response = await http.get(url, headers: {
      'X-Naver-Client-Id': _naverClientId,
      'X-Naver-Client-Secret': _naverClientSecret,
    });

    if (response.statusCode != 200) {
      debugPrint('[KOK Source] Naver API ${response.statusCode}');
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

  // ── YouTube ──

  Future<List<Map<String, dynamic>>> collectFromYouTube() async {
    if (_youtubeApiKey.isEmpty) {
      debugPrint('[KOK Source] YouTube API key missing');
      return [];
    }

    final results = <Map<String, dynamic>>[];

    // 2개 쿼리 로테이션
    for (int i = 0; i < 2; i++) {
      final query = _youtubeQueries[(_youtubeIdx + i) % _youtubeQueries.length];
      try {
        final videos = await _searchYouTubeVideos(query: query, maxResults: 10);
        debugPrint('[KOK Source] YouTube "$query": ${videos.length} videos');

        for (final video in videos.take(5)) {
          final title = video['title'] as String? ?? '';

          // 쇼츠/챌린지/마이너 콘텐츠 제외
          if (_trashPatterns.hasMatch(title)) continue;
          if (!_mentionsMajor(title)) continue;

          final videoId = video['videoId'] as String;
          List<String> comments = [];
          try {
            comments = await _fetchYouTubeComments(videoId, maxResults: 20);
          } catch (_) {}

          results.add({
            'title': title,
            'snippet': video['description'] ?? '',
            'url': 'https://www.youtube.com/watch?v=$videoId',
            'source': 'youtube',
            'published_at': video['publishedAt'] ?? '',
            'comments': comments,
            'channel': video['channelTitle'] ?? '',
          });
        }
      } catch (e) {
        debugPrint('[KOK Source] YouTube "$query" failed: $e');
      }
    }
    _youtubeIdx += 2;

    return results;
  }

  Future<List<Map<String, dynamic>>> _searchYouTubeVideos({
    required String query,
    int maxResults = 10,
  }) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet'
      '&q=${Uri.encodeComponent(query)}'
      '&type=video'
      '&order=relevance'
      '&regionCode=KR'
      '&relevanceLanguage=ko'
      '&videoDuration=medium'
      '&maxResults=$maxResults'
      '&publishedAfter=${_hoursAgo(72)}'
      '&key=$_youtubeApiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      debugPrint('[KOK Source] YouTube API ${response.statusCode}');
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

  // ── Filters ──

  /// 메이저 아이돌/소속사 언급이 있는 뉴스만 통과
  List<Map<String, dynamic>> _filterMajorOnly(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final title = item['title'] as String? ?? '';
      final snippet = item['snippet'] as String? ?? '';
      final combined = '$title $snippet';

      if (_trashPatterns.hasMatch(combined)) return false;

      return _mentionsMajor(combined);
    }).toList();
  }

  bool _mentionsMajor(String text) {
    final lower = text.toLowerCase();
    for (final name in _majorArtists) {
      if (lower.contains(name.toLowerCase())) return true;
    }
    for (final name in _majorAgencies) {
      if (lower.contains(name.toLowerCase())) return true;
    }
    // 일반 K-pop 업계 키워드 (아이돌 전체에 해당하는 빅 이슈)
    const industryKeywords = ['빌보드', 'billboard', '그래미', 'grammy', '멜론', 'melon',
      '음방 1위', '차트 1위', '월드투어', 'world tour', '시상식', '대상'];
    for (final kw in industryKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  // ── Utils ──

  String _hoursAgo(int hours) =>
      DateTime.now().toUtc().subtract(Duration(hours: hours)).toIso8601String();

  String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&apos;', "'")
      .trim();
}
