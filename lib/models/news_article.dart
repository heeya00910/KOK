class NewsArticle {
  final String id;

  // KOK Card Structure
  final String issueTitleEn;
  final String issueTitleEs;
  final String whatHappenedEn;
  final String whatHappenedEs;
  final String whyItMattersEn;
  final String whyItMattersEs;
  final String koreanReactionSummaryEn;
  final String koreanReactionSummaryEs;
  final List<TranslatedReaction> topReactions;
  final String contextForFansEn;
  final String contextForFansEs;
  final List<SourceLink> originalSources;

  // Content type & tier
  final String contentType;
  final String contentTier;
  final String labelEn;
  final String labelEs;
  final String confidenceLevel;
  final Map<String, dynamic> extraData;

  // Meta
  final String imageUrl;
  final List<String> issueTags;
  final List<String> artistTags;
  final DateTime publishedAt;
  final String sentiment; // positive, negative, mixed, neutral
  final int reactionSampleSize;
  final int viewCount;
  final ContentSafety safetyLevel;

  NewsArticle({
    required this.id,
    required this.issueTitleEn,
    required this.issueTitleEs,
    required this.whatHappenedEn,
    required this.whatHappenedEs,
    required this.whyItMattersEn,
    required this.whyItMattersEs,
    required this.koreanReactionSummaryEn,
    required this.koreanReactionSummaryEs,
    required this.topReactions,
    required this.contextForFansEn,
    required this.contextForFansEs,
    required this.originalSources,
    required this.imageUrl,
    required this.issueTags,
    required this.artistTags,
    required this.publishedAt,
    this.contentType = 'KOK_ISSUE_CARD',
    this.contentTier = 'heavy',
    this.labelEn = 'Issue',
    this.labelEs = 'Tema',
    this.confidenceLevel = 'high',
    this.extraData = const {},
    this.sentiment = 'neutral',
    this.reactionSampleSize = 0,
    this.viewCount = 0,
    this.safetyLevel = ContentSafety.safe,
  });

  String issueTitle(String lang) => lang == 'es' ? issueTitleEs : issueTitleEn;
  String whatHappened(String lang) => lang == 'es' ? whatHappenedEs : whatHappenedEn;
  String whyItMatters(String lang) => lang == 'es' ? whyItMattersEs : whyItMattersEn;
  String koreanReactionSummary(String lang) => lang == 'es' ? koreanReactionSummaryEs : koreanReactionSummaryEn;
  String contextForFans(String lang) => lang == 'es' ? contextForFansEs : contextForFansEn;
  String label(String lang) => lang == 'es' ? labelEs : labelEn;

  bool get isSnack => contentType != 'KOK_ISSUE_CARD';

  List<String> get allTags => [...issueTags, ...artistTags];

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'] ?? '',
      issueTitleEn: json['issue_title_en'] ?? '',
      issueTitleEs: json['issue_title_es'] ?? '',
      whatHappenedEn: json['what_happened_en'] ?? '',
      whatHappenedEs: json['what_happened_es'] ?? '',
      whyItMattersEn: json['why_it_matters_en'] ?? '',
      whyItMattersEs: json['why_it_matters_es'] ?? '',
      koreanReactionSummaryEn: json['korean_reaction_summary_en'] ?? '',
      koreanReactionSummaryEs: json['korean_reaction_summary_es'] ?? '',
      topReactions: (json['top_reactions'] as List?)
              ?.map((r) => TranslatedReaction.fromJson(r))
              .toList() ??
          [],
      contextForFansEn: json['context_for_fans_en'] ?? '',
      contextForFansEs: json['context_for_fans_es'] ?? '',
      originalSources: (json['original_sources'] as List?)
              ?.map((s) => SourceLink.fromJson(s))
              .toList() ??
          [],
      imageUrl: json['image_url'] ?? '',
      issueTags: List<String>.from(json['issue_tags'] ?? []),
      artistTags: List<String>.from(json['artist_tags'] ?? []),
      publishedAt: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      contentType: json['content_type'] ?? 'KOK_ISSUE_CARD',
      contentTier: json['content_tier'] ?? 'heavy',
      labelEn: json['label_en'] ?? 'Issue',
      labelEs: json['label_es'] ?? 'Tema',
      confidenceLevel: json['confidence_level'] ?? 'high',
      extraData: Map<String, dynamic>.from(json['extra_data'] ?? {}),
      sentiment: json['sentiment'] ?? 'neutral',
      reactionSampleSize: json['reaction_sample_size'] ?? 0,
      viewCount: json['view_count'] ?? 0,
      safetyLevel: ContentSafety.fromString(json['safety_level'] ?? 'safe'),
    );
  }
}

class TranslatedReaction {
  final String id;
  final String contentEn;
  final String contentEs;
  final int likes;
  final String source; // Naver, Daum, YouTube, TheQoo, etc.

  TranslatedReaction({
    required this.id,
    required this.contentEn,
    required this.contentEs,
    required this.likes,
    required this.source,
  });

  String content(String lang) => lang == 'es' ? contentEs : contentEn;

  factory TranslatedReaction.fromJson(Map<String, dynamic> json) {
    return TranslatedReaction(
      id: json['id'] ?? '',
      contentEn: json['content_en'] ?? '',
      contentEs: json['content_es'] ?? '',
      likes: json['likes'] ?? 0,
      source: json['source'] ?? '',
    );
  }
}

class SourceLink {
  final String title;
  final String url;
  final String type; // article, video, official

  SourceLink({
    required this.title,
    required this.url,
    required this.type,
  });

  factory SourceLink.fromJson(Map<String, dynamic> json) {
    return SourceLink(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? 'article',
    );
  }
}

enum ContentSafety {
  safe,
  reviewNeeded,
  blocked;

  static ContentSafety fromString(String s) {
    return switch (s) {
      'review_needed' => ContentSafety.reviewNeeded,
      'blocked' => ContentSafety.blocked,
      _ => ContentSafety.safe,
    };
  }
}
