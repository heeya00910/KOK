import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../models/news_article.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';
import '../widgets/language_toggle.dart';

class ArticleDetailPage extends StatefulWidget {
  final NewsArticle article;
  const ArticleDetailPage({super.key, required this.article});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _sourcesExpanded = false;

  NewsArticle get _a => widget.article;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lang = provider.language;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMeta(lang),
                    _buildIssueTitle(lang),
                    _sectionDivider(),
                    ..._buildContentBody(lang),
                    _sectionDivider(),
                    _buildTopReactions(lang),
                    _sectionDivider(),
                    _buildUserComments(provider, lang),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
          _buildCommentInput(provider, lang),
        ],
      ),
    );
  }

  // ── App Bar ──

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: KokColors.background,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        ),
      ),
      actions: const [
        Padding(padding: EdgeInsets.only(right: 16), child: LanguageToggle()),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _a.imageUrl.isNotEmpty && _a.imageUrl.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: _a.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildDetailFallbackImage(),
                  )
                : _buildDetailFallbackImage(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    KokColors.background.withAlpha(200),
                    KokColors.background,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Meta ──

  Widget _buildMeta(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          _sentimentBadge(),
          const SizedBox(width: 8),
          Text(_formatTimeAgo(_a.publishedAt),
              style: const TextStyle(fontSize: 12, color: KokColors.textMuted)),
          const Spacer(),
          ..._a.artistTags.take(2).map((tag) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('#$tag',
                    style: const TextStyle(fontSize: 12, color: KokColors.accentLight, fontWeight: FontWeight.w600)),
              )),
        ],
      ),
    );
  }

  Widget _buildDetailFallbackImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            KokColors.primary.withAlpha(60),
            KokColors.surface,
            KokColors.accent.withAlpha(40),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded, color: KokColors.primary.withAlpha(80), size: 48),
            const SizedBox(height: 8),
            Text(
              _a.artistTags.isNotEmpty ? _a.artistTags.first : 'K-POP',
              style: TextStyle(
                color: KokColors.textMuted.withAlpha(120),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sentimentBadge() {
    final (icon, color, label) = switch (_a.sentiment) {
      'positive' || 'supportive' => (Icons.trending_up_rounded, KokColors.success, 'Supportive'),
      'negative' || 'critical' => (Icons.trending_down_rounded, KokColors.error, 'Critical'),
      'mixed' || 'divided' => (Icons.swap_vert_rounded, KokColors.warning, 'Mixed'),
      'amused' => (Icons.sentiment_very_satisfied_rounded, const Color(0xFFFFB74D), 'Amused'),
      _ => (Icons.horizontal_rule_rounded, KokColors.textMuted, 'Neutral'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('KR $label', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Issue Title ──

  Widget _buildIssueTitle(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text(
        _a.issueTitle(lang),
        style: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w800,
          color: KokColors.textPrimary, height: 1.3, letterSpacing: -0.5,
        ),
      ),
    );
  }

  // ── Content type routing ──

  List<Widget> _buildContentBody(String lang) {
    return switch (_a.contentType) {
      'KOREAN_BUZZ_SNACK' => _bodyBuzzSnack(lang),
      'REACTION_SPLIT' => _bodyReactionSplit(lang),
      'KOREAN_COMMENT_MOOD' => _bodyCommentMood(lang),
      'STAGE_REACTION_SNACK' => _bodyStageReaction(lang),
      'KEYWORD_PULSE' => _bodyKeywordPulse(lang),
      'WHY_KOREANS_CARE' => _bodyWhyKoreansCare(lang),
      'NOT_A_BIG_ISSUE_BUT' => _bodyNotBigIssue(lang),
      _ => _bodyIssueCard(lang),
    };
  }

  List<Widget> _bodyIssueCard(String lang) {
    return [
      _buildSection(icon: Icons.article_rounded, title: lang == 'es' ? 'Qué pasó' : 'What happened', body: _a.whatHappened(lang)),
      _sectionDivider(),
      _buildSection(icon: Icons.flag_rounded, title: lang == 'es' ? 'Por qué importa en Corea' : 'Why it matters in Korea', body: _a.whyItMatters(lang)),
      _sectionDivider(),
      _buildKoreanReaction(lang),
      _sectionDivider(),
      _buildContextForFans(lang),
      if (_a.originalSources.isNotEmpty) ...[_sectionDivider(), _buildOriginalSources(lang)],
    ];
  }

  List<Widget> _bodyBuzzSnack(String lang) {
    return [
      _buildSection(icon: Icons.flash_on_rounded, title: lang == 'es' ? 'Qué se nota' : 'What\'s being noticed', body: _a.whatHappened(lang)),
      if (_a.koreanReactionSummary(lang).isNotEmpty) ...[
        _sectionDivider(),
        _buildSection(icon: Icons.chat_rounded, title: lang == 'es' ? 'Punto de reacción' : 'Korean reaction point', body: _a.koreanReactionSummary(lang)),
      ],
    ];
  }

  List<Widget> _bodyReactionSplit(String lang) {
    final sideA = (lang == 'es' ? _a.extraData['side_a_es'] : _a.extraData['side_a_en']) as String? ?? '';
    final sideB = (lang == 'es' ? _a.extraData['side_b_es'] : _a.extraData['side_b_en']) as String? ?? '';
    final meaning = (lang == 'es' ? _a.extraData['what_the_split_means_es'] : _a.extraData['what_the_split_means_en']) as String? ?? _a.whatHappened(lang);

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.swap_horiz_rounded, lang == 'es' ? 'Opiniones encontradas' : 'Fans Are Split'),
          const SizedBox(height: 16),
          _splitBox(Icons.thumb_up_alt_rounded, KokColors.success, lang == 'es' ? 'Algunos dicen...' : 'Some say...', sideA),
          const SizedBox(height: 10),
          _splitBox(Icons.thumb_down_alt_rounded, KokColors.warning, lang == 'es' ? 'Otros dicen...' : 'Others say...', sideB),
        ]),
      ),
      _sectionDivider(),
      _buildSection(icon: Icons.psychology_rounded, title: lang == 'es' ? 'Qué significa la división' : 'What the split means', body: meaning),
    ];
  }

  Widget _splitBox(IconData icon, Color color, String label, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(fontSize: 14, color: KokColors.textPrimary, height: 1.7)),
      ]),
    );
  }

  List<Widget> _bodyCommentMood(String lang) {
    final mood = _a.extraData['main_mood'] as String? ?? _a.sentiment;
    final dist = _a.extraData['mood_distribution'] as Map<String, dynamic>?;

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.mood_rounded, lang == 'es' ? 'Sentimiento de fans' : 'Fan Sentiment'),
          const SizedBox(height: 16),
          _moodBadge(mood),
          if (dist != null) ...[const SizedBox(height: 16), _moodBars(dist)],
        ]),
      ),
      _sectionDivider(),
      _buildSection(icon: Icons.summarize_rounded, title: lang == 'es' ? 'Resumen del sentimiento' : 'Sentiment Summary', body: _a.whatHappened(lang)),
    ];
  }

  Widget _moodBadge(String mood) {
    final normalized = mood.toLowerCase().trim();
    final (color, displayLabel) = switch (normalized) {
      'positive' || 'mostly positive' || 'supportive' => (KokColors.success, 'Positive'),
      'critical' || 'mildly critical' || 'strongly critical' => (KokColors.error, 'Critical'),
      'amused' => (const Color(0xFFFFB74D), 'Amused'),
      'curious' => (KokColors.accent, 'Curious'),
      'mixed' || 'divided' => (KokColors.warning, 'Mixed'),
      _ => (KokColors.warning, 'Mixed'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(50))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Text(displayLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _moodBars(Map<String, dynamic> dist) {
    final colorMap = <String, Color>{
      'positive': KokColors.success, 'supportive': KokColors.success,
      'amused': const Color(0xFFFFB74D), 'curious': KokColors.accent,
      'critical': KokColors.error, 'negative': KokColors.error,
      'mixed': KokColors.warning, 'neutral': KokColors.textMuted,
    };
    final entries = dist.entries.where((e) => (e.value as num? ?? 0) > 0).toList()
      ..sort((a, b) => ((b.value as num?) ?? 0).compareTo((a.value as num?) ?? 0));

    return Column(children: entries.map((e) {
      final pct = (e.value as num?)?.toInt() ?? 0;
      final color = colorMap[e.key] ?? KokColors.textMuted;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 70, child: Text(e.key, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(height: 8, child: Stack(children: [
              Container(color: KokColors.surfaceLight),
              FractionallySizedBox(widthFactor: pct / 100, child: Container(color: color)),
            ])),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 32, child: Text('$pct%', style: const TextStyle(fontSize: 11, color: KokColors.textMuted), textAlign: TextAlign.right)),
        ]),
      );
    }).toList());
  }

  List<Widget> _bodyStageReaction(String lang) {
    final videoTitle = _a.extraData['video_title'] as String? ?? '';
    final focus = (lang == 'es' ? _a.extraData['performance_focus_es'] : _a.extraData['performance_focus_en']) as String? ?? '';

    return [
      if (videoTitle.isNotEmpty) Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: KokColors.success.withAlpha(10), borderRadius: BorderRadius.circular(12), border: Border.all(color: KokColors.success.withAlpha(30))),
          child: Row(children: [
            const Icon(Icons.play_circle_filled_rounded, size: 20, color: KokColors.success),
            const SizedBox(width: 10),
            Expanded(child: Text(videoTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KokColors.textPrimary))),
          ]),
        ),
      ),
      if (videoTitle.isNotEmpty) _sectionDivider(),
      if (focus.isNotEmpty) ...[
        _buildSection(icon: Icons.visibility_rounded, title: lang == 'es' ? 'Enfoque de reacción' : 'Performance focus', body: focus),
        _sectionDivider(),
      ],
      _buildSection(icon: Icons.chat_rounded, title: lang == 'es' ? 'Reacciones coreanas' : 'Korean reactions', body: _a.whatHappened(lang)),
    ];
  }

  List<Widget> _bodyKeywordPulse(String lang) {
    final keywords = _a.extraData['keywords'] as List? ?? [];
    final summary = (lang == 'es' ? _a.extraData['overall_summary_es'] : _a.extraData['overall_summary_en']) as String? ?? _a.whatHappened(lang);

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.trending_up_rounded, lang == 'es' ? 'Palabras clave de hoy' : 'Today\'s keywords'),
          const SizedBox(height: 16),
          ...keywords.take(5).map<Widget>((kw) {
            final keyword = kw is Map ? (kw['keyword'] ?? '') : kw.toString();
            final reason = kw is Map ? (kw[lang == 'es' ? 'reason_es' : 'reason_en'] ?? '') : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: KokColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7C4DFF).withAlpha(30))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFF7C4DFF).withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.tag_rounded, size: 16, color: Color(0xFF7C4DFF)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(keyword.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KokColors.textPrimary)),
                  if (reason.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(reason.toString(), style: const TextStyle(fontSize: 12, color: KokColors.textSecondary, height: 1.4)),
                  ],
                ])),
              ]),
            );
          }),
        ]),
      ),
      _sectionDivider(),
      _buildSection(icon: Icons.summarize_rounded, title: lang == 'es' ? 'Resumen' : 'Overview', body: summary),
    ];
  }

  List<Widget> _bodyWhyKoreansCare(String lang) {
    final whyMatters = (lang == 'es' ? _a.extraData['why_it_matters_es'] : _a.extraData['why_it_matters_en']) as String? ?? _a.whyItMatters(lang);
    final fansMiss = (lang == 'es' ? _a.extraData['what_global_fans_might_miss_es'] : _a.extraData['what_global_fans_might_miss_en']) as String? ?? _a.contextForFans(lang);

    return [
      _buildSection(icon: Icons.school_rounded, title: lang == 'es' ? 'Explicación' : 'Explanation', body: _a.whatHappened(lang)),
      _sectionDivider(),
      if (whyMatters.isNotEmpty) ...[
        _buildSection(icon: Icons.flag_rounded, title: lang == 'es' ? 'Por qué importa en Corea' : 'Why it matters in Korea', body: whyMatters),
        _sectionDivider(),
      ],
      if (fansMiss.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withAlpha(12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00897B).withAlpha(40)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFF00897B)),
                const SizedBox(width: 8),
                Text(lang == 'es' ? 'Lo que los fans globales podrían perderse' : 'What global fans might miss',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00897B))),
              ]),
              const SizedBox(height: 12),
              Text(fansMiss, style: const TextStyle(fontSize: 14, color: KokColors.textPrimary, height: 1.7)),
            ]),
          ),
        ),
    ];
  }

  List<Widget> _bodyNotBigIssue(String lang) {
    final observation = _a.whatHappened(lang);
    final whyNoticed = (lang == 'es' ? _a.extraData['why_it_is_being_noticed_es'] : _a.extraData['why_it_is_being_noticed_en']) as String? ?? '';
    final caution = (lang == 'es' ? _a.extraData['caution_note_es'] : _a.extraData['caution_note_en']) as String? ?? '';

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(lang == 'es' ? 'No es gran cosa, pero...' : 'Not a big issue, but...',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: KokColors.textMuted.withAlpha(180))),
      ),
      const SizedBox(height: 8),
      _buildSection(icon: Icons.remove_red_eye_rounded, title: lang == 'es' ? 'Qué se observa' : 'What\'s being noticed', body: observation),
      if (whyNoticed.isNotEmpty) ...[
        _sectionDivider(),
        _buildSection(icon: Icons.help_outline_rounded, title: lang == 'es' ? 'Por qué se nota' : 'Why it\'s being noticed', body: whyNoticed),
      ],
      if (caution.isNotEmpty) ...[
        _sectionDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: KokColors.warning.withAlpha(10), borderRadius: BorderRadius.circular(12), border: Border.all(color: KokColors.warning.withAlpha(30))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: KokColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text(caution, style: const TextStyle(fontSize: 13, color: KokColors.textSecondary, height: 1.5))),
            ]),
          ),
        ),
      ],
    ];
  }

  // ── Generic Section ──

  Widget _buildSection({required IconData icon, required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon, title),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 15, color: KokColors.textSecondary, height: 1.8)),
        ],
      ),
    );
  }

  // ── Korean Reaction ──

  Widget _buildKoreanReaction(String lang) {
    final (icon, color, label) = switch (_a.sentiment) {
      'positive' || 'supportive' => (Icons.trending_up_rounded, KokColors.success, lang == 'es' ? 'Positivo' : 'Supportive'),
      'negative' || 'critical' => (Icons.trending_down_rounded, KokColors.error, lang == 'es' ? 'Cr\u00edtico' : 'Critical'),
      'mixed' || 'divided' => (Icons.swap_vert_rounded, KokColors.warning, lang == 'es' ? 'Mixto' : 'Mixed'),
      'amused' => (Icons.sentiment_very_satisfied_rounded, const Color(0xFFFFB74D), lang == 'es' ? 'Divertido' : 'Amused'),
      _ => (Icons.horizontal_rule_rounded, KokColors.textMuted, lang == 'es' ? 'Neutral' : 'Neutral'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.groups_rounded, lang == 'es' ? 'Reacci\u00f3n coreana' : 'Korean public reaction'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withAlpha(15), color.withAlpha(5)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(label,
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatNumber(_a.reactionSampleSize)} ${lang == 'es' ? 'fuentes consultadas' : 'sources referenced'}',
                      style: const TextStyle(fontSize: 12, color: KokColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_a.koreanReactionSummary(lang),
                    style: const TextStyle(fontSize: 14, color: KokColors.textPrimary, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Reactions ──

  Widget _buildTopReactions(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.format_quote_rounded, lang == 'es' ? 'Reacciones destacadas' : 'Top Fan Reactions'),
          const SizedBox(height: 12),
          if (_validReactions(lang).isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KokColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KokColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: KokColors.textMuted.withAlpha(150)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang == 'es'
                          ? 'Sin comentarios reales disponibles. Consulta el resumen de reacciones arriba.'
                          : 'No real comments available. Check the reaction summary above.',
                      style: TextStyle(fontSize: 13, color: KokColors.textMuted.withAlpha(180), height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._validReactions(lang).asMap().entries.map((entry) {
              return _buildReactionCard(entry.value, entry.key, lang);
            }),
        ],
      ),
    );
  }

  List<TranslatedReaction> _validReactions(String lang) {
    return _a.topReactions.where((r) => r.content(lang).trim().isNotEmpty).toList();
  }

  Widget _buildReactionCard(TranslatedReaction reaction, int index, String lang) {
    final rankIcons = [Icons.looks_one_rounded, Icons.looks_two_rounded, Icons.looks_3_rounded];
    final rankIcon = index < 3 ? rankIcons[index] : Icons.chat_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KokColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KokColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(rankIcon, size: 18, color: KokColors.primary),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: KokColors.accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(reaction.source,
                    style: const TextStyle(fontSize: 11, color: KokColors.accentLight, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              const Icon(Icons.thumb_up_alt_rounded, size: 14, color: KokColors.primary),
              const SizedBox(width: 4),
              Text(_formatNumber(reaction.likes),
                  style: const TextStyle(fontSize: 13, color: KokColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(reaction.content(lang),
              style: const TextStyle(fontSize: 14, color: KokColors.textPrimary, height: 1.6, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ── Context for Fans ──

  Widget _buildContextForFans(String lang) {
    return _buildSection(
      icon: Icons.lightbulb_outline_rounded,
      title: lang == 'es' ? 'Contexto para fans globales' : 'Context for global fans',
      body: _a.contextForFans(lang),
    );
  }

  // ── Original Sources ──

  Widget _buildOriginalSources(String lang) {
    final sources = _a.originalSources;
    final previewCount = 2;
    final hasMore = sources.length > previewCount;
    final visible = _sourcesExpanded ? sources : sources.take(previewCount).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  Icons.link_rounded,
                  '${lang == 'es' ? 'Fuentes originales' : 'Original sources'} (${sources.length})',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...visible.map((source) => _buildSourceLink(source)),
          if (hasMore)
            GestureDetector(
              onTap: () => setState(() => _sourcesExpanded = !_sourcesExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sourcesExpanded
                          ? (lang == 'es' ? 'Mostrar menos' : 'Show less')
                          : (lang == 'es' ? 'Ver ${sources.length - previewCount} mas' : 'Show ${sources.length - previewCount} more'),
                      style: TextStyle(fontSize: 12, color: KokColors.primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _sourcesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: KokColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceLink(SourceLink source) {
    final typeIcon = switch (source.type) {
      'video' => Icons.play_circle_outline_rounded,
      'official' => Icons.verified_rounded,
      _ => Icons.open_in_new_rounded,
    };

    return GestureDetector(
      onTap: () => _launchUrl(source.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KokColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KokColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(typeIcon, size: 18, color: KokColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(source.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: KokColors.textPrimary)),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: KokColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── User Comments ──

  Widget _buildUserComments(AppProvider provider, String lang) {
    final comments = provider.getCommentsForArticle(_a.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionAccent(),
              const SizedBox(width: 10),
              const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: KokColors.textPrimary),
              const SizedBox(width: 6),
              Text(lang == 'es' ? 'Comentarios de fans' : 'Fan comments',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: KokColors.textPrimary)),
              const SizedBox(width: 8),
              _countBadge(comments.length),
            ],
          ),
          const SizedBox(height: 12),
          if (comments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KokColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KokColors.border, width: 0.5),
              ),
              child: Center(
                child: Text(lang == 'es' ? 'S\u00e9 el primero en comentar' : 'Be the first to comment',
                    style: const TextStyle(fontSize: 14, color: KokColors.textMuted)),
              ),
            )
          else
            ...comments.map((comment) => _buildCommentTile(comment, provider, lang)),
        ],
      ),
    );
  }

  Widget _buildCommentTile(comment, AppProvider provider, String lang) {
    final isMine = provider.isMyComment(comment);
    final canManage = isMine || provider.isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KokColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KokColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: KokColors.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    comment.nickname.isNotEmpty ? comment.nickname[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KokColors.accentLight),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  children: [
                    Text(comment.nickname,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KokColors.textPrimary)),
                    if (comment.nationality.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: KokColors.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(UserProfile.shortCode(comment.nationality),
                            style: const TextStyle(fontSize: 10, color: KokColors.accentLight, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (comment.fandom.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: KokColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(comment.fandom,
                            style: const TextStyle(fontSize: 10, color: KokColors.primary, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(_formatTimeAgo(comment.createdAt),
                  style: const TextStyle(fontSize: 11, color: KokColors.textMuted)),
              if (comment.isEdited) ...[
                const SizedBox(width: 4),
                Text(lang == 'es' ? '(editado)' : '(edited)',
                    style: const TextStyle(fontSize: 10, color: KokColors.textMuted, fontStyle: FontStyle.italic)),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => provider.likeComment(_a.id, comment.id),
                child: Row(
                  children: [
                    Icon(
                      provider.hasLikedComment(comment.id) ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                      size: 14,
                      color: provider.hasLikedComment(comment.id) ? KokColors.primary : KokColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text('${comment.likes}',
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.hasLikedComment(comment.id) ? KokColors.primary : KokColors.textMuted,
                        )),
                  ],
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showCommentActions(comment, provider, lang, isMine),
                  child: const Icon(Icons.more_horiz_rounded, size: 18, color: KokColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.content,
              style: const TextStyle(fontSize: 14, color: KokColors.textPrimary, height: 1.5)),
        ],
      ),
    );
  }

  void _showCommentActions(comment, AppProvider provider, String lang, bool isMine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: KokColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: KokColors.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            if (isMine)
              _actionTile(
                icon: Icons.edit_outlined,
                label: lang == 'es' ? 'Editar comentario' : 'Edit comment',
                onTap: () {
                  Navigator.pop(context);
                  _showEditCommentDialog(comment, provider, lang);
                },
              ),
            _actionTile(
              icon: Icons.delete_outline_rounded,
              label: lang == 'es' ? 'Eliminar comentario' : 'Delete comment',
              color: KokColors.error,
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteComment(comment, provider, lang);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final c = color ?? KokColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c)),
          ],
        ),
      ),
    );
  }

  void _showEditCommentDialog(comment, AppProvider provider, String lang) {
    final controller = TextEditingController(text: comment.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KokColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lang == 'es' ? 'Editar comentario' : 'Edit comment',
          style: const TextStyle(color: KokColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: KokColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: KokColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'es' ? 'Cancelar' : 'Cancel', style: const TextStyle(color: KokColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && text != comment.content) {
                provider.editComment(_a.id, comment.id, text);
              }
              Navigator.pop(ctx);
            },
            child: Text(lang == 'es' ? 'Guardar' : 'Save',
                style: const TextStyle(color: KokColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(comment, AppProvider provider, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KokColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lang == 'es' ? 'Eliminar comentario' : 'Delete comment',
          style: const TextStyle(color: KokColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          lang == 'es' ? 'Esta acción no se puede deshacer.' : 'This action cannot be undone.',
          style: const TextStyle(color: KokColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'es' ? 'Cancelar' : 'Cancel', style: const TextStyle(color: KokColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteComment(_a.id, comment.id);
              Navigator.pop(ctx);
            },
            child: Text(lang == 'es' ? 'Eliminar' : 'Delete',
                style: const TextStyle(color: KokColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Comment Input ──

  Widget _buildCommentInput(AppProvider provider, String lang) {
    final hasNickname = provider.profile.nickname.isNotEmpty;

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: KokColors.surface,
          border: const Border(top: BorderSide(color: KokColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: KokColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: KokColors.border, width: 0.5),
                ),
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  enabled: hasNickname,
                  style: const TextStyle(color: KokColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hasNickname
                        ? (lang == 'es' ? 'Escribe un comentario...' : 'Write a comment...')
                        : (lang == 'es' ? 'Configura tu nickname primero' : 'Set your nickname first'),
                    hintStyle: const TextStyle(color: KokColors.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (!hasNickname) return;
                final text = _commentController.text.trim();
                if (text.isEmpty) return;
                provider.addComment(_a.id, text);
                _commentController.clear();
                _commentFocusNode.unfocus();
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: hasNickname
                      ? const LinearGradient(colors: [KokColors.gradientStart, KokColors.gradientEnd])
                      : null,
                  color: hasNickname ? null : KokColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_rounded, size: 18,
                    color: hasNickname ? Colors.white : KokColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared Helpers ──

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        _sectionAccent(),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: KokColors.textPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: KokColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _sectionAccent() {
    return Container(
      width: 4, height: 20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [KokColors.gradientStart, KokColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: KokColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: const TextStyle(fontSize: 12, color: KokColors.primary, fontWeight: FontWeight.w700)),
    );
  }

  Widget _sectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Divider(color: KokColors.border, height: 1),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatNumber(int number) {
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
