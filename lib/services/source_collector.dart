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
  //  한국어 → 공식 영어명 매핑 (AI 오역 방지)
  // ═══════════════════════════════════════════

  static const koToOfficialName = <String, String>{
    '방탄소년단': 'BTS', '스트레이키즈': 'Stray Kids', '세븐틴': 'SEVENTEEN',
    '엔하이픈': 'ENHYPEN', '투모로우바이투게더': 'TXT', '엑소': 'EXO',
    '에이티즈': 'ATEEZ', '제로베이스원': 'ZEROBASEONE',
    '보이넥스트도어': 'BOYNEXTDOOR', '트레저': 'TREASURE',
    '라이즈': 'RIIZE', '몬스타엑스': 'MONSTA X',
    '블랙핑크': 'BLACKPINK', '에스파': 'aespa', '뉴진스': 'NewJeans',
    '아이브': 'IVE', '르세라핌': 'LE SSERAFIM', '트와이스': 'TWICE',
    '잇지': 'ITZY', '여자아이들': '(G)I-DLE', '엔믹스': 'NMIXX',
    '아일릿': 'ILLIT', '베이비몬스터': 'BABYMONSTER',
    '케플러': 'Kep1er', '레드벨벳': 'Red Velvet',
    '아이즈나': 'izna',
    '정국': 'Jung Kook', '지민': 'Jimin', '뷔': 'V', '슈가': 'SUGA',
    '리사': 'Lisa', '제니': 'Jennie', '로제': 'Rosé', '지수': 'Jisoo',
    '아이유': 'IU', '임영웅': 'Lim Young-woong',
    '민희진': 'Min Hee-jin', '카리나': 'Karina', '윈터': 'Winter',
    '하이브': 'HYBE', '빅히트': 'BIGHIT', '어도어': 'ADOR',
    '스타쉽': 'STARSHIP', '플레디스': 'PLEDIS', '큐브': 'CUBE',
  };

  static String getOfficialName(String koName) =>
      koToOfficialName[koName] ?? koName;

  static String buildNameMappingPrompt() {
    final entries = koToOfficialName.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    return 'ARTIST NAME MAP (MUST use these EXACT English names, never guess): $entries';
  }

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

  /// 네이버용 쿼리: 반드시 [특정 아티스트명] + [사건 키워드]
  /// "아이돌" 같은 범용어 사용 금지 — 쓰레기 유입 차단
  List<String> _generateNaverQueries() {
    final artists = _pickArtists(4);
    final suffixes = [
      '컴백', '논란', '신곡', '월드투어', '빌보드',
      '소속사', '계약', '시상식', '한국 반응',
    ];

    final queries = <String>[];
    for (final artist in artists) {
      final suffix = suffixes[_naverIdx % suffixes.length];
      queries.add('"$artist" $suffix');
      _naverIdx++;
    }

    return queries;
  }

  /// YouTube용 쿼리: [특정 아티스트명] + [이슈 키워드]
  List<String> _generateYouTubeQueries() {
    final artists = _pickArtists(4);
    final suffixes = [
      '논란 정리', '최신 소식', '반응 모음', '팬 반응',
      '이슈 정리', '컴백 반응', '한국 반응',
    ];

    final queries = <String>[];
    for (final artist in artists) {
      final suffix = suffixes[_youtubeIdx % suffixes.length];
      queries.add('$artist $suffix');
      _youtubeIdx++;
    }

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
  //  Artist Weight System
  //  팬덤 규모 + 글로벌 인지도 기반 (1~10)
  //  향후 API 기반 주 1회 자동 업데이트 가능하도록 분리
  // ═══════════════════════════════════════════

  static final Map<String, int> _artistWeights = {
    // Tier S — weight 10
    'BTS': 10, '방탄소년단': 10,
    'BLACKPINK': 10, '블랙핑크': 10,
    // Tier S- — weight 9
    'Jung Kook': 9, '정국': 9, 'Lisa': 9, '리사': 9,
    'Jennie': 9, '제니': 9, 'Rosé': 9, '로제': 9,
    'Stray Kids': 9, '스트레이키즈': 9,
    'SEVENTEEN': 9, '세븐틴': 9,
    'KATSEYE': 9,
    // Tier A — weight 8
    'NewJeans': 8, '뉴진스': 8,
    'aespa': 8, '에스파': 8,
    'ENHYPEN': 8, '엔하이픈': 8,
    'TWICE': 8, '트와이스': 8,
    // Tier A- — weight 7
    'IVE': 7, '아이브': 7,
    'LE SSERAFIM': 7, '르세라핌': 7,
    'TXT': 7, '투모로우바이투게더': 7,
    'ATEEZ': 7, '에이티즈': 7,
    'NCT': 7,
    'RIIZE': 7, '라이즈': 7,
    'BABYMONSTER': 7, '베이비몬스터': 7,
    'EXO': 7, '엑소': 7,
    // Tier B — weight 6
    'ITZY': 6, '잇지': 6,
    'NMIXX': 6, '엔믹스': 6,
    'ILLIT': 6, '아일릿': 6,
    'TWS': 6,
    'KISS OF LIFE': 6,
    'ZEROBASEONE': 6, '제로베이스원': 6, 'ZB1': 6,
    'BOYNEXTDOOR': 6, '보이넥스트도어': 6,
    'MONSTA X': 6, '몬스타엑스': 6,
    'TREASURE': 6, '트레저': 6,
    '(G)I-DLE': 6, '여자아이들': 6,
    'Red Velvet': 6, '레드벨벳': 6,
    'Kep1er': 6, '케플러': 6,
    // Tier C — weight 4~5
    'Jimin': 5, '지민': 5, 'V': 5, '뷔': 5, 'SUGA': 5, '슈가': 5,
    'Jisoo': 5, '지수': 5, 'IU': 5, '아이유': 5,
    'izna': 5, '아이즈나': 5, 'Hearts2Hearts': 5, 'MEOVV': 5,
    '임영웅': 4,
    // 소속사 — weight 5
    'HYBE': 5, '하이브': 5, 'SM': 5, 'YG': 5, 'JYP': 5,
    'ADOR': 5, '어도어': 5, 'STARSHIP': 4, '스타쉽': 4,
    '민희진': 5,
  };

  static int getArtistWeight(String name) => _artistWeights[name] ?? 3;

  // ═══════════════════════════════════════════
  //  Chart Bonus — 차트 순위 기반 가중치 (플러스 알파)
  //  차트 데이터 없어도 시스템 정상 작동
  // ═══════════════════════════════════════════

  static Map<String, int> _chartBonus = {};

  /// 파이프라인 실행 전 차트 데이터를 로드해서 보너스 맵 생성
  static void loadChartBonus(List<Map<String, dynamic>> chartData) {
    _chartBonus = {};
    for (final entry in chartData) {
      final name = entry['artist_name'] as String? ?? '';
      final rank = entry['rank'] as int? ?? 999;
      if (name.isEmpty) continue;

      int bonus;
      if (rank == 1) {
        bonus = 3;
      } else if (rank <= 3) {
        bonus = 2;
      } else if (rank <= 10) {
        bonus = 1;
      } else {
        bonus = 0;
      }
      if (bonus > 0) _chartBonus[name] = bonus;
    }
  }

  static int _getChartBonus(String text) {
    if (_chartBonus.isEmpty) return 0;
    int maxBonus = 0;
    final lower = text.toLowerCase();
    for (final entry in _chartBonus.entries) {
      if (lower.contains(entry.key.toLowerCase()) && entry.value > maxBonus) {
        maxBonus = entry.value;
      }
    }
    return maxBonus;
  }

  static final _nonKpopNoise = RegExp(
    r'(컴투스|com2us|넷마블|넥슨|크래프톤|카카오게임|게임빌|'
    r'주가|코스피|코스닥|증시|부동산|정치|국회|대통령|'
    r'날씨|교통|사건사고|범죄|재판|검찰|경찰|'
    r'야구|축구|농구|배구|올림픽|월드컵|프로야구|KBO|EPL)',
    caseSensitive: false,
  );

  /// 텍스트에서 가장 높은 artist_weight를 찾는다
  static int _findMaxWeight(String text) {
    if (_nonKpopNoise.hasMatch(text)) return 0;

    int maxWeight = 0;
    final lower = text.toLowerCase();
    for (final entry in _artistWeights.entries) {
      final key = entry.key.toLowerCase();
      if (key.length <= 2) {
        final pattern = RegExp('(^|[^a-z가-힣])${RegExp.escape(key)}([^a-z가-힣]|\$)', caseSensitive: false);
        if (pattern.hasMatch(lower) && entry.value > maxWeight) {
          maxWeight = entry.value;
        }
      } else {
        if (lower.contains(key) && entry.value > maxWeight) {
          maxWeight = entry.value;
        }
      }
    }
    return maxWeight;
  }

  // K-pop과 무관한 연예인 (배우/셰프/웹툰작가 등)
  static const _nonKpopCelebs = [
    // 배우/예능인
    '김수현', '백종원', '기안84', '류준열', '한소희', '송혜교',
    '현빈', '손예진', '이민호', '공유', '이종석', '박서준', '김태리',
    '전지현', '이정재', '황정민', '마동석', '유재석', '강호동',
    '신동엽', '박나래', '전현무', '이광수', '김종국',
    // 비활동/배우전환 아이돌 (현재 K-pop 활동 안 함)
    '옥택연', '택연', '2PM', '이준호', '준호', '장우영', '닉쿤',
    '윤수일', '나훈아', '조용필',
    '지예은', '바타', '미연',
    // 중국/일본 연예인
    '타오', 'Tao',
  ];

  // ═══════════════════════════════════════════
  //  Feed Score 계산
  //  feed_score = artist_weight + issue_score
  //             + korean_reaction_score + freshness_score
  //             - low_quality_penalty
  // ═══════════════════════════════════════════

  static const _issueKeywordsHigh = <String, int>{
    '논란': 5, '사과문': 5, '라이브 논란': 5, '실력 논란': 5, '표절': 5,
    '계약': 5, '재계약': 5, '소속사 분쟁': 5, '탈퇴': 5, '복귀': 5,
    '불화': 5, '고소': 5, '소송': 5, '퇴출': 5, '폭로': 5,
  };
  static const _issueKeywordsMid = <String, int>{
    '월드투어': 4, '시상식': 4, '수상': 4, '그래미': 4, '코첼라': 4,
    '빌보드': 4, '차트': 4, '음원': 4, '1위': 4,
  };
  static const _issueKeywordsLow = <String, int>{
    '컴백': 3, '신곡': 3, '앨범': 3, '뮤직비디오': 3, '티저': 3,
    '콘셉트': 3, '초동': 3, '데뷔': 3,
  };
  static const _issueKeywordsMin = <String, int>{
    '열애설': 2, '공항패션': 2, '브랜드 앰버서더': 2, '콜라보': 2,
    '화보': 2, '팬미팅': 2, '콘서트': 2,
  };

  static const _reactionKeywordsList = [
    '한국 반응', '네티즌 반응', '커뮤니티 반응', '팬덤 반응',
    '베댓', '댓글', '여론', '갑론을박', '화제', '재조명', '해외 반응',
  ];

  /// feed_score 계산 — 통과 여부도 함께 반환
  Map<String, dynamic> calculateFeedScore(Map<String, dynamic> item) {
    final title = (item['title'] as String? ?? '');
    final snippet = (item['snippet'] as String? ?? '');
    final combined = '$title $snippet'.toLowerCase();
    final publishedAt = item['published_at'] as String? ?? '';

    // ── 1. artist_weight ──
    final artistWeight = _findMaxWeight(combined);

    // ★ 핵심: _artistWeights에 등록된 아티스트가 없으면 즉시 탈락
    // "아이돌", "걸그룹" 같은 범용 키워드만으로는 통과 불가
    if (artistWeight == 0) {
      return {'score': -1, 'pass': false, 'artist_weight': 0};
    }

    // 비 K-pop 연예인이 주인공인 기사 제외
    for (final name in _nonKpopCelebs) {
      if (title.toLowerCase().contains(name.toLowerCase())) {
        return {'score': -1, 'pass': false, 'artist_weight': 0};
      }
    }

    // ── 2. issue_score ──
    int issueScore = 0;
    for (final e in _issueKeywordsHigh.entries) {
      if (combined.contains(e.key)) { issueScore = e.value; break; }
    }
    if (issueScore == 0) {
      for (final e in _issueKeywordsMid.entries) {
        if (combined.contains(e.key)) { issueScore = e.value; break; }
      }
    }
    if (issueScore == 0) {
      for (final e in _issueKeywordsLow.entries) {
        if (combined.contains(e.key)) { issueScore = e.value; break; }
      }
    }
    if (issueScore == 0) {
      for (final e in _issueKeywordsMin.entries) {
        if (combined.contains(e.key)) { issueScore = e.value; break; }
      }
    }

    // ── 3. korean_reaction_score ──
    int reactionScore = 0;
    for (final kw in _reactionKeywordsList) {
      if (combined.contains(kw)) { reactionScore = 5; break; }
    }

    // ── 4. freshness_score ──
    int freshnessScore = 0;
    if (publishedAt.isNotEmpty) {
      try {
        final pub = DateTime.parse(publishedAt);
        final hoursAgo = DateTime.now().toUtc().difference(pub).inHours;
        if (hoursAgo <= 24) {
          freshnessScore = 3;
        } else if (hoursAgo <= 72) {
          freshnessScore = 2;
        } else if (hoursAgo <= 168) {
          freshnessScore = 1;
        } else {
          freshnessScore = -3;
        }
      } catch (_) {
        freshnessScore = 0;
      }
    }

    // ── 5. low_quality_penalty ──
    int penalty = 0;
    if (_trashPatterns.hasMatch(combined)) {
      bool hasOverride = false;
      for (final kw in _overrideKeywords) {
        if (combined.contains(kw)) { hasOverride = true; break; }
      }
      if (!hasOverride) penalty = 5;
    }

    // ── 6. chart_bonus (플러스 알파, 없어도 OK) ──
    final chartBonus = _getChartBonus(combined);

    // ── feed_score ──
    final feedScore = artistWeight + issueScore + reactionScore + freshnessScore + chartBonus - penalty;

    // ── 통과 기준 ──
    bool pass;
    if (artistWeight >= 8) {
      pass = feedScore >= 10;
    } else if (artistWeight <= 5) {
      pass = (issueScore + reactionScore) >= 8;
    } else {
      pass = feedScore >= 12;
    }

    return {
      'score': feedScore,
      'pass': pass,
      'artist_weight': artistWeight,
      'issue_score': issueScore,
      'reaction_score': reactionScore,
      'freshness_score': freshnessScore,
      'chart_bonus': chartBonus,
      'penalty': penalty,
    };
  }

  /// 하위 호환: 기존 코드에서 int만 필요한 곳
  int calculateRelevanceScore(Map<String, dynamic> item) {
    final result = calculateFeedScore(item);
    return result['pass'] == true ? (result['score'] as int) : -1;
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

    // feed_score 기반 필터 + 정렬
    final scored = <Map<String, dynamic>>[];
    for (final item in results) {
      final fs = calculateFeedScore(item);
      if (fs['pass'] == true) {
        item['_relevance'] = fs['score'] as int;
        item['_artist_weight'] = fs['artist_weight'] as int;
        scored.add(item);
      }
    }
    scored.sort((a, b) => (b['_relevance'] as int).compareTo(a['_relevance'] as int));

    debugPrint('[KOK Source] Naver total: ${results.length}→${scored.length} (feed_score pass)');
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
        'image_url': '',
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

    // feed_score 기반 필터 + 정렬
    final scored = <Map<String, dynamic>>[];
    for (final item in results) {
      final fs = calculateFeedScore(item);
      if (fs['pass'] == true) {
        item['_relevance'] = fs['score'] as int;
        item['_artist_weight'] = fs['artist_weight'] as int;
        scored.add(item);
      }
    }
    scored.sort((a, b) => (b['_relevance'] as int).compareTo(a['_relevance'] as int));

    debugPrint('[KOK Source] YouTube total: ${results.length}→${scored.length} (feed_score pass)');
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
      '&type=video&order=date'
      '&regionCode=KR&relevanceLanguage=ko'
      '&maxResults=$maxResults'
      '&publishedAfter=${_hoursAgo(168)}'
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
  //  Naver 블로그/카페 — 여론·반응 수집
  // ═══════════════════════════════════════════

  /// 특정 뉴스 사건에 대한 한국인 반응을 블로그/카페/YouTube에서 수집
  Future<List<Map<String, dynamic>>> collectReactions(String issueTitle, {String snippet = ''}) async {
    final reactions = <Map<String, dynamic>>[];

    // 1) 네이버 블로그/카페
    if (_naverClientId.isNotEmpty) {
      final queries = _buildReactionQueries(issueTitle, snippet);
      for (final query in queries) {
        try {
          final blogResults = await _searchNaverBlog(query, display: 8);
          reactions.addAll(blogResults);
        } catch (e) {
          debugPrint('[KOK Source] Blog "$query" failed: $e');
        }
        try {
          final cafeResults = await _searchNaverCafe(query, display: 8);
          reactions.addAll(cafeResults);
        } catch (e) {
          debugPrint('[KOK Source] Cafe "$query" failed: $e');
        }
      }
    }

    // 2) YouTube 댓글 (해당 뉴스 관련 영상에서 베스트 댓글 수집)
    if (_youtubeApiKey.isNotEmpty) {
      try {
        final clean = issueTitle
            .replaceAll(RegExp(r'[#\[\]"…💖😵‍💫🎵✨🔥]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final ytQuery = clean.length > 50 ? clean.substring(0, 50) : clean;
        final videos = await _searchYouTubeVideos(query: ytQuery, maxResults: 3);
        for (final video in videos.take(2)) {
          final videoId = video['videoId'] as String;
          try {
            final comments = await _fetchYouTubeComments(videoId, maxResults: 10);
            for (final c in comments) {
              if ((c['text'] as String).length >= 10) {
                reactions.add({
                  'text': c['text'],
                  'likes': c['likes'],
                  'source': 'YouTube',
                  'url': 'https://www.youtube.com/watch?v=$videoId',
                });
              }
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[KOK Source] YouTube reactions failed: $e');
      }
    }

    debugPrint('[KOK Source] Reactions for "$issueTitle": ${reactions.length} snippets');
    return reactions;
  }

  /// 뉴스 제목의 핵심 내용을 그대로 살려서 검색 쿼리 생성
  List<String> _buildReactionQueries(String title, String snippet) {
    final clean = title
        .replaceAll(RegExp(r'[#\[\]"…💖😵‍💫🎵✨🔥]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final core = clean.length > 40 ? clean.substring(0, 40) : clean;

    // 아티스트 이름 추출 (제목에서)
    String? artistKo;
    for (final entry in koToOfficialName.entries) {
      if (clean.contains(entry.key)) {
        artistKo = entry.key;
        break;
      }
    }

    final queries = [
      '$core 반응',
      '$core 여론',
    ];

    // 아티스트명 + 핵심 키워드 조합으로 3번째 쿼리 추가
    if (artistKo != null) {
      queries.add('$artistKo 팬 반응');
    }

    return queries;
  }

  Future<List<Map<String, dynamic>>> _searchNaverBlog(String query, {int display = 10}) async {
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/blog.json'
      '?query=${Uri.encodeComponent(query)}'
      '&display=$display&sort=sim',
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
        'text': desc.length > 200 ? desc.substring(0, 200) : desc,
        'title': title,
        'source': 'Naver Blog',
        'url': item['link'] ?? '',
      };
    }).where((r) => (r['text'] as String).length >= 20).toList();
  }

  Future<List<Map<String, dynamic>>> _searchNaverCafe(String query, {int display = 10}) async {
    final url = Uri.parse(
      'https://openapi.naver.com/v1/search/cafearticle.json'
      '?query=${Uri.encodeComponent(query)}'
      '&display=$display&sort=sim',
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
        'text': desc.length > 200 ? desc.substring(0, 200) : desc,
        'title': title,
        'source': 'Naver Cafe',
        'url': item['link'] ?? '',
      };
    }).where((r) => (r['text'] as String).length >= 20).toList();
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
