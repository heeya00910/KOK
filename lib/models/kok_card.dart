class KokCard {
  final String id;
  final String titleEn;
  final String titleEs;
  final String talkingAboutEn;
  final String talkingAboutEs;
  final String whatHappenedEn;
  final String whatHappenedEs;
  final String reactionSummaryEn;
  final String reactionSummaryEs;
  final String contextEn;
  final String contextEs;
  final List<String> reactionsEn;
  final List<String> reactionsEs;
  final List<Map<String, dynamic>> sourceLinks;
  final List<String> tags;
  final String issueType;
  final String reactionTone;
  final String riskLevel;
  final String? imageUrl;
  final DateTime? publishedAt;

  KokCard({
    required this.id,
    required this.titleEn,
    required this.titleEs,
    required this.talkingAboutEn,
    required this.talkingAboutEs,
    required this.whatHappenedEn,
    required this.whatHappenedEs,
    required this.reactionSummaryEn,
    required this.reactionSummaryEs,
    required this.contextEn,
    required this.contextEs,
    required this.reactionsEn,
    required this.reactionsEs,
    required this.sourceLinks,
    required this.tags,
    required this.issueType,
    required this.reactionTone,
    required this.riskLevel,
    this.imageUrl,
    this.publishedAt,
  });

  factory KokCard.fromJson(Map<String, dynamic> json) {
    return KokCard(
      id: json['id'] ?? '',
      titleEn: json['title_en'] ?? '',
      titleEs: json['title_es'] ?? '',
      talkingAboutEn: json['what_people_are_talking_about_en'] ?? '',
      talkingAboutEs: json['what_people_are_talking_about_es'] ?? '',
      whatHappenedEn: json['what_happened_en'] ?? '',
      whatHappenedEs: json['what_happened_es'] ?? '',
      reactionSummaryEn: json['korean_reaction_summary_en'] ?? '',
      reactionSummaryEs: json['korean_reaction_summary_es'] ?? '',
      contextEn: json['context_for_global_fans_en'] ?? '',
      contextEs: json['context_for_global_fans_es'] ?? '',
      reactionsEn: List<String>.from(json['representative_reactions_en'] ?? []),
      reactionsEs: List<String>.from(json['representative_reactions_es'] ?? []),
      sourceLinks: List<Map<String, dynamic>>.from(
        (json['source_links'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      ),
      tags: List<String>.from(json['tags'] ?? []),
      issueType: json['issue_type'] ?? 'OTHER',
      reactionTone: json['reaction_tone'] ?? 'mixed',
      riskLevel: json['risk_level'] ?? 'low',
      imageUrl: json['image_url'],
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'])
          : null,
    );
  }

  String title(String lang) => lang == 'es' ? titleEs : titleEn;
  String talkingAbout(String lang) => lang == 'es' ? talkingAboutEs : talkingAboutEn;
  String whatHappened(String lang) => lang == 'es' ? whatHappenedEs : whatHappenedEn;
  String reactionSummary(String lang) => lang == 'es' ? reactionSummaryEs : reactionSummaryEn;
  String context(String lang) => lang == 'es' ? contextEs : contextEn;
  List<String> reactions(String lang) => lang == 'es' ? reactionsEs : reactionsEn;

  String get timeAgo {
    if (publishedAt == null) return '';
    final diff = DateTime.now().difference(publishedAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
