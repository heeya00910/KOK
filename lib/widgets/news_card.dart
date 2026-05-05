import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/tags.dart';
import '../models/news_article.dart';
import '../providers/app_provider.dart';

class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  final bool isLocked;

  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppProvider>().language;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: KokColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KokColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTags(),
                  const SizedBox(height: 10),
                  _buildTitle(lang),
                  const SizedBox(height: 8),
                  _buildWhatHappened(lang),
                  const SizedBox(height: 12),
                  _buildReactionPreview(lang),
                  const SizedBox(height: 12),
                  _buildFooter(lang),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: CachedNetworkImage(
            imageUrl: article.imageUrl,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Shimmer.fromColors(
              baseColor: KokColors.surfaceLight,
              highlightColor: KokColors.surface,
              child: Container(height: 180, color: KokColors.surfaceLight),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 180,
              color: KokColors.surfaceLight,
              child: const Center(
                child: Icon(Icons.music_note_rounded, color: KokColors.textMuted, size: 40),
              ),
            ),
          ),
        ),
        if (isLocked)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                color: Colors.black.withAlpha(150),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: KokColors.surfaceLight.withAlpha(200),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: KokColors.primary.withAlpha(100)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: KokColors.primary, size: 16),
                        SizedBox(width: 6),
                        Text('Watch 2 ads to unlock',
                            style: TextStyle(color: KokColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 12,
          left: 12,
          child: _SentimentBadge(sentiment: article.sentiment),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _DdayBadge(publishedAt: article.publishedAt),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...article.issueTags.take(2).map((tag) => _IssueChip(tag: tag)),
        ...article.artistTags.take(3).map((tag) => _ArtistChip(tag: tag)),
      ],
    );
  }

  Widget _buildTitle(String lang) {
    return Text(
      article.issueTitle(lang),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: KokColors.textPrimary, height: 1.3),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildWhatHappened(String lang) {
    return Text(
      article.whatHappened(lang),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: KokColors.textSecondary, height: 1.5),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildReactionPreview(String lang) {
    if (article.topReactions.isEmpty) return const SizedBox.shrink();
    final reaction = article.topReactions.first;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KokColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KokColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: KokColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text('K', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: KokColors.primary)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reaction.content(lang),
              style: const TextStyle(fontSize: 12, color: KokColors.textSecondary, fontStyle: FontStyle.italic, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(String lang) {
    final timeAgo = _formatTimeAgo(article.publishedAt);
    final sampleText = lang == 'es' ? 'reacciones' : 'reactions';

    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 14, color: KokColors.textMuted),
        const SizedBox(width: 4),
        Text(timeAgo, style: const TextStyle(fontSize: 12, color: KokColors.textMuted)),
        const SizedBox(width: 16),
        const Icon(Icons.forum_outlined, size: 14, color: KokColors.textMuted),
        const SizedBox(width: 4),
        Text('${_formatNumber(article.reactionSampleSize)}+ $sampleText',
            style: const TextStyle(fontSize: 12, color: KokColors.textMuted)),
        const Spacer(),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: KokColors.textMuted.withAlpha(100)),
      ],
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
}

// ── Reusable sub-widgets ──

class _SentimentBadge extends StatelessWidget {
  final String sentiment;
  const _SentimentBadge({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (sentiment) {
      'positive' => (Icons.trending_up_rounded, KokColors.success, 'Positive'),
      'negative' => (Icons.trending_down_rounded, KokColors.error, 'Critical'),
      'mixed' => (Icons.swap_vert_rounded, KokColors.warning, 'Divided'),
      _ => (Icons.horizontal_rule_rounded, KokColors.textMuted, 'Neutral'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('KR $label',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  final String tag;
  const _IssueChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final icon = KokTags.issueTagIcons[tag] ?? Icons.tag_rounded;
    final display = KokTags.issueTagDisplay[tag] ?? tag;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: KokColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: KokColors.primaryLight),
          const SizedBox(width: 4),
          Text(display,
              style: const TextStyle(color: KokColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DdayBadge extends StatelessWidget {
  final DateTime publishedAt;
  const _DdayBadge({required this.publishedAt});

  @override
  Widget build(BuildContext context) {
    final daysLeft = 14 - DateTime.now().difference(publishedAt).inDays;
    final clamped = daysLeft.clamp(0, 14);

    final (color, bgAlpha) = clamped <= 2
        ? (KokColors.error, 180)
        : clamped <= 5
            ? (KokColors.warning, 170)
            : (Colors.white70, 150);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(bgAlpha),
        borderRadius: BorderRadius.circular(8),
        border: clamped <= 1 ? Border.all(color: KokColors.error.withAlpha(120), width: 0.5) : null,
      ),
      child: Text(
        'D-$clamped',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class _ArtistChip extends StatelessWidget {
  final String tag;
  const _ArtistChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: KokColors.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('#$tag',
          style: const TextStyle(color: KokColors.accentLight, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
