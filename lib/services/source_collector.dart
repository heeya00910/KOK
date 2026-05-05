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

  // ═══════════════════════════════════════════
  //  아티스트 목록
  // ═══════════════════════════════════════════

  static const _majorArtists = [
    // ── 빅 보이그룹 ──
    'BTS', '방탄소년단',
    'Stray Kids', '스트레이키즈',
    'SEVENTEEN', '세븐틴',
    'ENHYPEN', '엔하이픈',
    'TXT', '투모로우바이투게더',
    'NCT', 'EXO', '엑소',
    'ATEEZ', '에이티즈',
    'ZEROBASEONE', '제로베이스원',
    'BOYNEXTDOOR', '보이넥스트도어',
    'TREASURE', '트레저',
    'RIIZE', '라이즈',
    'TWS', 'MONSTA X', '몬스타엑스',
    // ── 빅 걸그룹 ──
    'BLACKPINK', '블랙핑크',
    'aespa', '에스파',
    'NewJeans', '뉴진스',
    'IVE', '아이브',
    'LE SSERAFIM', '르세라핌',
    'TWICE', '트와이스',
    'ITZY', '잇지',
    '(G)I-DLE', '여자아이들',
    'NMIXX', '엔믹스',
    'ILLIT', '아일릿',
    'BABYMONSTER', '베이비몬스터',
    'KISS OF LIFE',
    'Kep1er', '케플러',
    'Red Velvet', '레드벨벳',
    'KATSEYE', 'MEOVV',
    'izna', '아이즈나',
    'Hearts2Hearts',
    // ── 솔로 ──
    'Jung Kook', '정국', 'Jimin', '지민', 'V', '뷔', 'SUGA', '슈가',
    'Lisa', '리사', 'Jennie', '제니', 'Rosé', '로제', 'Jisoo', '지수',
    'IU', '아이유', '임영웅',
    // ── 신규 추가 ──
    'HUNTR/X', 'SAJA BOYS', 'ALLDAY PROJECT',
  ];

  static const _majorAgencies = [
    'HYBE', '하이브', 'SM', 'YG', 'JYP',
    'STARSHIP', '스타쉽', 'PLEDIS', '플레디스',
    'CUBE', '큐브', 'ADOR', '어도어',
    'KOZ', 'BIGHIT', '빅히트',
  ];

  // 검색 쿼리 조합용 아티스트 (한국어 이름 우선)
  static const _searchArtists = [
    '방탄소년단', '블랙핑크', '뉴진스', '에스파', '아이브', '르세라핌',
    '세븐틴', '스트레이키즈', '엔하이픈', '투모로우바이투게더',
    '트와이스', '잇지', '엔믹스', '여자아이들',
    '정국', '지민', '제니', '로제', '리사', '아이유',
    '엑소', 'NCT', '에이티즈', '제로베이스원', '라이즈',
    '아일릿', '베이비몬스터', 'KATSEYE', 'MONSTA X',
  ];

  // ═══════════════════════════════════════════
  //  키워드 목록
  // ═══════════════════════════════════════════

  static const _eventKeywords = [
    '컴백', '신곡', '앨범', '티저', '뮤직비디오', '콘셉트', '초동',
    '빌보드', '스포티파이', '멜론', '차트 1위', '음방 1위',
    '월드투어', '콘서트', '팬미팅', '시상식', '수상', '그래미', '코첼라',
    '콜라보', '브랜드 앰버서더', '공항패션',
    '열애설', '논란', '사과문', '불화설',
    '계약', '재계약', '탈퇴', '복귀', '군백기', '입대', '전역',
    '소속사 분쟁', '표절 의혹', '라이브 논란', '실력 논란',
  ];

  static const _reactionKeywords = [
    '한국 반응', '네티즌 반응', '팬덤 반응', '커뮤니티 반응',
    '베댓', '댓글', '여론', '갑론을박', '화제', '재조명', '해외 반응',
  ];

  // 제외해도 되는 키워드가 있어도 이것이 함께 있으면 살리는 키워드
  static const _overrideKeywords = [
    '논란', '한국 반응', '네티즌 반응', '팬덤 반응',
    '차트', '빌보드', '컴백', '신곡', '월드투어',
    '소속사', '계약', '재계약',
  ];

  static final _trashPatterns = RegExp(
    r'(#shorts|#챌린지|랜덤댄스|커버댄스|dance ?cover|random ?play|'
    r'먹방|ASMR|unboxing|언박싱|앨범깡|'
    r'reaction|리액션|#쇼츠|틱톡|tiktok)',
    caseSensitive: false,
  );

  // 추가 키워드 (팬 플랫폼/문화)
  static const _extraKeywords = [
    'Weverse', '위버스', 'Bubble', '버블', 'DearU', '디어유',
    '팬플랫폼', '슈퍼팬', '팬싸', '포카', '굿즈',
  ];

  // 신뢰 소스
  static const _trustedSources = [
    'sports.khan.co.kr', 'starnewskorea.com', 'tenasia.hankyung.com',
    'soompi.com', 'n.news.naver.com', 'entertain.naver.com',
    'newsen.com', 'xportsnews.com', 'mydaily.co.kr', 'osen.mt.co.kr',
    'news1.kr', 'koreaherald.com', 'allkpop.com', 'koreaboo.com',
    'dispatch.co.kr', 'theqoo.net', 'instiz.net',
  ];

  // 신뢰 YouTube 채널
  static const _trustedChannels = [
    'HYBE LABELS', '1theK', 'Stone Music', 'Mnet K-POP',
    'KBS Kpop', 'MBCkpop', 'SBS K-POP', 'BANGTANTV',
    'BLACKPINK', 'SMTOWN', 'JYP Entertainment', 'staraborned',
    '연예 뒤통령', '연예가중계', '비디오머그',
  ];

  int _naverIdx = 0;
  int _youtubeIdx = 0;
  int _artistIdx = 0;

  // ═══════════════════════════════════════════
  //  검색 쿼리 생성
  // ═══════════════════════════════════════════

  /// 네이버용 쿼리 생성: [아이돌] + 사건성 키워드
  List<String> _generateNaverQueries() {
    final artists = _pickArtists(3);
    final naverSuffixes = [
      '컴백', '신곡', '논란', '한국 반응', '차트',
      '빌보드', '월드투어', '소속사', '계약', '재계약',
    ];

    final queries = <String>[];
    for (final artist in artists) {
      final suffix = naverSuffixes[_naverIdx % naverSuffixes.length];
      queries.add('$artist $suffix');
      _naverIdx++;
    }
    // 업계 전반 쿼리 1개 추가
    const industryQueries = [
      '케이팝 빌보드 차트', '아이돌 컴백 소식', '하이브 YG SM JYP 뉴스',
      '아이돌 논란 여론', '케이팝 시상식 수상', '아이돌 월드투어 콘서트',
    ];
    queries.add(industryQueries[_naverIdx % industryQueries.length]);

    return queries;
  }

  /// YouTube용 쿼리 생성: [아이돌] + 이슈 키워드
  List<String> _generateYouTubeQueries() {
    final artists = _pickArtists(2);
    final ytSuffixes = [
      '이슈 정리', '논란 정리', '컴백 반응',
      '한국 반응', '해외 반응', '근황', '소속사 이슈',
    ];

    final queries = <String>[];
    for (final artist in artists) {
      final suffix = ytSuffixes[_youtubeIdx % ytSuffixes.length];
      queries.add('$artist $suffix');
      _youtubeIdx++;
    }
    // 업계 전반 1개
    const general = [
      '케이팝 핫이슈 정리', '아이돌 논란 총정리', '케이팝 뉴스 이번주',
    ];
    queries.add(general[_youtubeIdx % general.length]);

    return queries;
  }

  /// 아티스트 로테이션 (매번 다른 조합)
  List<String> _pickArtists(int count) {
    final picked = <String>[];
    for (int i = 0; i < count; i++) {
      picked.add(_searchArtists[(_artistIdx + i) % _searchArtists.length]);
    }
    _artistIdx += count;
    return picked;
  }

  // ═══════════════════════════════════════════
  //  Relevance Scoring
  // ═══════════════════════════════════════════

  int calculateRelevanceScore(Map<String, dynamic> item) {
    int score = 0;
    final title = (item['title'] as String? ?? '').toLowerCase();
    final snippet = (item['snippet'] as String? ?? '').toLowerCase();
    final url = (item['url'] as String? ?? '').toLowerCase();
    final channel = (item['channel'] as String? ?? '').toLowerCase();
    final combined = '$title $snippet';
    final publishedAt = item['published_at'] as String? ?? '';

    // 메이저 아티스트 언급: +3
    for (final name in _majorArtists) {
      if (combined.contains(name.toLowerCase())) {
        score += 3;
        break;
      }
    }
    for (final name in _majorAgencies) {
      if (combined.contains(name.toLowerCase())) {
        score += 2;
        break;
      }
    }

    // 사건성 키워드: +3
    for (final kw in _eventKeywords) {
      if (combined.contains(kw)) {
        score += 3;
        break;
      }
    }

    // 반응 키워드: +4
    for (final kw in _reactionKeywords) {
      if (combined.contains(kw)) {
        score += 4;
        break;
      }
    }

    // 차트/월드투어/수상/논란/계약: +4
    const highImpact = ['차트', '빌보드', '월드투어', '수상', '시상식',
      '논란', '계약', '재계약', '그래미', '코첼라'];
    for (final kw in highImpact) {
      if (combined.contains(kw)) {
        score += 4;
        break;
      }
    }

    // 팬 플랫폼/문화 키워드: +1
    for (final kw in _extraKeywords) {
      if (combined.contains(kw.toLowerCase())) {
        score += 1;
        break;
      }
    }

    // 제외 키워드 단독 포함: -5 (단, override 키워드가 함께 있으면 면제)
    if (_trashPatterns.hasMatch(combined)) {
      bool hasOverride = false;
      for (final kw in _overrideKeywords) {
        if (combined.contains(kw)) {
          hasOverride = true;
          break;
        }
      }
      if (!hasOverride) score -= 5;
    }

    // 72시간 이내: +2
    if (publishedAt.isNotEmpty) {
      try {
        final pub = DateTime.parse(publishedAt);
        if (DateTime.now().toUtc().difference(pub).inHours <= 72) {
          score += 2;
        }
      } catch (_) {
        score += 1; // 파싱 실패 시 최소 점수
      }
    }

    // 신뢰 소스: +2
    for (final src in _trustedSources) {
      if (url.contains(src)) {
        score += 2;
        break;
      }
    }
    for (final ch in _trustedChannels) {
      if (channel.contains(ch.toLowerCase())) {
        score += 2;
        break;
      }
    }

    // 댓글 있으면: +2
    final comments = item['comments'] as List?;
    if (comments != null && comments.isNotEmpty) {
      score += 2;
    }

    return score;
  }

  // ═══════════════════════════════════════════
  //  Naver News
  // ═══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> collectFromNaverNews() async {
    if (_naverClientId.isEmpty || _naverClientSecret.isEmpty) {
      debugPrint('[KOK Source] Naver API keys missing');
      return [];
    }

    final queries = _generateNaverQueries();
    final results = <Map<String, dynamic>>[];

    for (final query in queries) {
      try {
        final items = await _searchNaverNews(query, display: 15);
        results.addAll(items);
        debugPrint('[KOK Source] Naver "$query": ${items.length} items');
      } catch (e) {
        debugPrint('[KOK Source] Naver "$query" failed: $e');
      }
    }

    // relevance score로 필터 + 정렬
    final scored = results.map((item) {
      item['_relevance'] = calculateRelevanceScore(item);
      return item;
    }).where((item) => (item['_relevance'] as int) >= 6).toList()
      ..sort((a, b) => (b['_relevance'] as int).compareTo(a['_relevance'] as int));

    debugPrint('[KOK Source] Naver total: ${results.length}→${scored.length} (score≥6)');
    return scored;
  }

  Future<List<Map<String, dynamic>>> _searchNaverNews(String query, {int display = 15}) async {
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/news.json'
      '?query=${Uri.encodeComponent(query)}'
      '&display=$display&sort=date&start=1',
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

  // ═══════════════════════════════════════════
  //  YouTube
  // ═══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> collectFromYouTube() async {
    if (_youtubeApiKey.isEmpty) {
      debugPrint('[KOK Source] YouTube API key missing');
      return [];
    }

    final queries = _generateYouTubeQueries();
    final results = <Map<String, dynamic>>[];

    for (final query in queries) {
      try {
        final videos = await _searchYouTubeVideos(query: query, maxResults: 10);
        debugPrint('[KOK Source] YouTube "$query": ${videos.length} videos');

        for (final video in videos.take(5)) {
          final videoId = video['videoId'] as String;
          List<Map<String, dynamic>> commentData = [];
          try {
            commentData = await _fetchYouTubeComments(videoId, maxResults: 20);
          } catch (_) {}

          results.add({
            'title': video['title'] ?? '',
            'snippet': video['description'] ?? '',
            'url': 'https://www.youtube.com/watch?v=$videoId',
            'source': 'youtube',
            'published_at': video['publishedAt'] ?? '',
            'comments': commentData.map((c) => c['text'] as String).toList(),
            'comment_data': commentData,
            'channel': video['channelTitle'] ?? '',
            'image_url': video['thumbnail'] ?? '',
          });
        }
      } catch (e) {
        debugPrint('[KOK Source] YouTube "$query" failed: $e');
      }
    }

    // relevance score로 필터 + 정렬
    final scored = results.map((item) {
      item['_relevance'] = calculateRelevanceScore(item);
      return item;
    }).where((item) => (item['_relevance'] as int) >= 6).toList()
      ..sort((a, b) => (b['_relevance'] as int).compareTo(a['_relevance'] as int));

    debugPrint('[KOK Source] YouTube total: ${results.length}→${scored.length} (score≥6)');
    return scored;
  }

  Future<List<Map<String, dynamic>>> _searchYouTubeVideos({
    required String query,
    int maxResults = 10,
  }) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet'
      '&q=${Uri.encodeComponent(query)}'
      '&type=video&order=relevance'
      '&regionCode=KR&relevanceLanguage=ko'
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
      final thumbnails = snippet['thumbnails'] ?? {};
      final thumb = thumbnails['high'] ?? thumbnails['medium'] ?? thumbnails['default'] ?? {};
      return <String, dynamic>{
        'videoId': item['id']?['videoId'] ?? '',
        'title': snippet['title'] ?? '',
        'description': snippet['description'] ?? '',
        'channelTitle': snippet['channelTitle'] ?? '',
        'publishedAt': snippet['publishedAt'] ?? '',
        'thumbnail': thumb['url'] ?? '',
      };
    }).where((v) => (v['videoId'] as String).isNotEmpty).toList();
  }

  /// 댓글 텍스트 + 실제 좋아요 수를 함께 반환
  Future<List<Map<String, dynamic>>> _fetchYouTubeComments(String videoId, {int maxResults = 20}) async {
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/commentThreads'
      '?part=snippet&videoId=$videoId'
      '&order=relevance&maxResults=$maxResults'
      '&textFormat=plainText&key=$_youtubeApiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final items = data['items'] as List? ?? [];

    return items.map((item) {
      final snippet = item['snippet']?['topLevelComment']?['snippet'];
      final text = (snippet?['textDisplay'] ?? '') as String;
      final likes = (snippet?['likeCount'] ?? 0) as int;
      return <String, dynamic>{
        'text': text,
        'likes': likes,
        'source': 'YouTube',
      };
    }).where((c) => (c['text'] as String).isNotEmpty).toList();
  }

  // ═══════════════════════════════════════════
  //  공개 메서드 (파이프라인에서 사용)
  // ═══════════════════════════════════════════

  bool isMajorArtistMentioned(String text) {
    final lower = text.toLowerCase();
    for (final name in _majorArtists) {
      if (lower.contains(name.toLowerCase())) return true;
    }
    for (final name in _majorAgencies) {
      if (lower.contains(name.toLowerCase())) return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════
  //  유틸
  // ═══════════════════════════════════════════

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
