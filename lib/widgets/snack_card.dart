import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/news_article.dart';
import '../providers/app_provider.dart';

class SnackCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const SnackCard({super.key, required this.article, required this.onTap});

  static const _typeMeta = <String, (Color, String, String)>{
    'KOREAN_BUZZ_SNACK': (KokColors.primary, 'Buzz', 'Buzz'),
    'REACTION_SPLIT': (KokColors.warning, 'Reaction Split', 'División de Reacción'),
    'KOREAN_COMMENT_MOOD': (KokColors.accent, 'Comment Mood', 'Ánimo de Comentarios'),
    'STAGE_REACTION_SNACK': (KokColors.success, 'Stage Reaction', 'Reacción en Vivo'),
    'KEYWORD_PULSE': (Color(0xFF7C4DFF), 'Keyword Pulse', 'Pulso de Palabras'),
    'WHY_KOREANS_CARE': (Color(0xFF00897B), 'Context', 'Contexto'),
    'NOT_A_BIG_ISSUE_BUT': (KokColors.textMuted, 'Small Buzz', 'Pequeño Buzz'),
  };

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppProvider>().language;
    final meta = _typeMeta[article.contentType];
    final badgeColor = meta?.$1 ?? KokColors.textMuted;
    final badgeLabel = lang == 'es' ? (meta?.$3 ?? '') : (meta?.$2 ?? '');

    final hasImage = article.imageUrl.isNotEmpty && article.imageUrl.startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: KokColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KokColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) _buildCompactImage(badgeLabel, badgeColor),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasImage) _buildBadge(badgeLabel, badgeColor),
                  if (!hasImage) const SizedBox(height: 8),
                  ..._buildBody(lang),
                  const SizedBox(height: 8),
                  _buildTimeFooter(lang),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactImage(String badgeLabel, Color badgeColor) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: CachedNetworkImage(
            imageUrl: article.imageUrl,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 120,
              color: KokColors.surfaceLight,
            ),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: _buildBadge(badgeLabel, badgeColor),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTimeFooter(String lang) {
    final diff = DateTime.now().difference(article.publishedAt);
    String ago;
    if (diff.inDays > 0) {
      ago = lang == 'es' ? 'hace ${diff.inDays}d' : '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      ago = lang == 'es' ? 'hace ${diff.inHours}h' : '${diff.inHours}h ago';
    } else {
      final m = diff.inMinutes.clamp(1, 59);
      ago = lang == 'es' ? 'hace ${m}m' : '${m}m ago';
    }
    return Text(
      ago,
      style: const TextStyle(fontSize: 10, color: KokColors.textMuted),
    );
  }

  List<Widget> _buildBody(String lang) {
    return switch (article.contentType) {
      'KOREAN_BUZZ_SNACK' => _buzzSnack(lang),
      'REACTION_SPLIT' => _reactionSplit(lang),
      'KOREAN_COMMENT_MOOD' => _commentMood(lang),
      'STAGE_REACTION_SNACK' => _stageReaction(lang),
      'KEYWORD_PULSE' => _keywordPulse(lang),
      'WHY_KOREANS_CARE' => _whyKoreansCare(lang),
      'NOT_A_BIG_ISSUE_BUT' => _notBigIssue(lang),
      _ => [_title(lang)],
    };
  }

  Widget _title(String lang) {
    return Text(
      article.issueTitle(lang),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: KokColors.textPrimary,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<Widget> _buzzSnack(String lang) {
    final body = article.whatHappened(lang);
    final reaction = article.koreanReactionSummary(lang);
    return [
      _title(lang),
      if (body.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(fontSize: 12, color: KokColors.textSecondary, height: 1.4),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      if (reaction.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          reaction,
          style: const TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: KokColors.textMuted,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ];
  }

  List<Widget> _reactionSplit(String lang) {
    final sideA = (lang == 'es'
        ? article.extraData['side_a_es'] as String?
        : article.extraData['side_a_en'] as String?) ?? (lang == 'es' ? 'Algunos dicen...' : 'Some say...');
    final sideB = (lang == 'es'
        ? article.extraData['side_b_es'] as String?
        : article.extraData['side_b_en'] as String?) ?? (lang == 'es' ? 'Otros dicen...' : 'Others say...');
    final summary = article.whatHappened(lang);

    return [
      _title(lang),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KokColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sideA,
                style: const TextStyle(fontSize: 11, color: KokColors.textSecondary, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: KokColors.border,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KokColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sideB,
                style: const TextStyle(fontSize: 11, color: KokColors.textSecondary, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
      if (summary.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          summary,
          style: const TextStyle(fontSize: 12, color: KokColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ];
  }

  List<Widget> _commentMood(String lang) {
    final mood = article.extraData['main_mood'] as String? ?? '';
    final dist = article.extraData['mood_distribution'] as Map<String, dynamic>?;
    final positive = dist != null ? (dist['positive'] as num?)?.toDouble() : null;
    final critical = dist != null ? (dist['critical'] as num?)?.toDouble() : null;
    final summary = article.whatHappened(lang);

    return [
      _title(lang),
      if (mood.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: KokColors.accent.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            mood,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KokColors.accentLight),
          ),
        ),
      ],
      if (positive != null && critical != null) ...[
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(
                  flex: positive.round().clamp(1, 100),
                  child: Container(color: KokColors.success),
                ),
                Expanded(
                  flex: (100 - positive.round()).clamp(1, 100),
                  child: Container(color: KokColors.error),
                ),
              ],
            ),
          ),
        ),
      ],
      if (summary.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          summary,
          style: const TextStyle(fontSize: 12, color: KokColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ];
  }

  List<Widget> _stageReaction(String lang) {
    final channel = article.extraData['video_title'] as String? ?? '';
    final body = article.whatHappened(lang);

    return [
      _title(lang),
      if (channel.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.play_circle_outline, size: 14, color: KokColors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                channel,
                style: const TextStyle(fontSize: 11, color: KokColors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
      if (body.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(fontSize: 12, color: KokColors.textSecondary, height: 1.4),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ];
  }

  List<Widget> _keywordPulse(String lang) {
    final pulseTitle = lang == 'es' ? "Pulso K-pop de Hoy" : "Today's K-pop Pulse";
    final keywords = article.extraData['keywords'] as List? ?? [];

    return [
      Text(
        pulseTitle,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KokColors.textPrimary),
      ),
      const SizedBox(height: 8),
      ...keywords.take(5).map<Widget>((kw) {
        final keyword = kw is Map ? (kw['keyword'] ?? '') : kw.toString();
        final reason = kw is Map ? (kw[lang == 'es' ? 'reason_es' : 'reason_en'] ?? '') : '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '·  ',
                style: TextStyle(fontSize: 12, color: Color(0xFF7C4DFF), fontWeight: FontWeight.w700),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: keyword.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KokColors.textPrimary),
                    ),
                    if (reason.toString().isNotEmpty)
                      TextSpan(
                        text: '  $reason',
                        style: const TextStyle(fontSize: 11, color: KokColors.textMuted),
                      ),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }),
    ];
  }

  List<Widget> _whyKoreansCare(String lang) {
    final body = article.whatHappened(lang);
    final miss = (lang == 'es'
        ? article.extraData['what_global_fans_might_miss_es'] as String?
        : article.extraData['what_global_fans_might_miss_en'] as String?) ?? article.contextForFans(lang);

    return [
      _title(lang),
      if (body.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(fontSize: 12, color: KokColors.textSecondary, height: 1.4),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      if (miss.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00897B).withAlpha(18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF00897B).withAlpha(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang == 'es' ? 'Lo que los fans globales podrían perderse' : 'What global fans might miss',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF00897B)),
              ),
              const SizedBox(height: 4),
              Text(
                miss,
                style: const TextStyle(fontSize: 11, color: KokColors.textSecondary, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _notBigIssue(String lang) {
    final prefix = lang == 'es' ? 'No es gran cosa, pero...' : 'Not a big issue, but...';
    final observation = article.whatHappened(lang);
    final caution = (lang == 'es'
        ? article.extraData['caution_note_es'] as String?
        : article.extraData['caution_note_en'] as String?) ?? '';

    return [
      Text(
        prefix,
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: KokColors.textMuted,
        ),
      ),
      if (observation.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          observation,
          style: const TextStyle(fontSize: 12, color: KokColors.textSecondary, height: 1.4),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      if (caution.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          caution,
          style: const TextStyle(fontSize: 10, color: KokColors.textMuted, height: 1.3),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ];
  }
}
