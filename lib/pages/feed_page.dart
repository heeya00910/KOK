import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/kok_logo.dart';
import '../widgets/language_toggle.dart';
import '../widgets/tag_filter_bar.dart';
import '../widgets/news_card.dart';
import '../widgets/ad_unlock_sheet.dart';
import 'article_detail_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onArticleTap(String articleId) {
    final provider = context.read<AppProvider>();

    if (provider.isArticleUnlocked(articleId) || provider.canViewFree) {
      provider.tryViewArticle(articleId);
      _navigateToDetail(articleId);
    } else {
      provider.startUnlockFlow(articleId);
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: AdUnlockSheet(
            onUnlocked: () => _navigateToDetail(articleId),
          ),
        ),
      );
    }
  }

  void _navigateToDetail(String articleId) {
    final provider = context.read<AppProvider>();
    final article = provider.articles.firstWhere((a) => a.id == articleId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailPage(article: article)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lang = provider.language;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(provider, lang),
            const SizedBox(height: 12),
            const TagFilterBar(),
            const SizedBox(height: 8),
            Expanded(
              child: provider.isLoading
                  ? _buildLoadingState()
                  : _buildArticleList(provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppProvider provider, String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              const KokLogo(fontSize: 28, showSubtitle: false),
              const Spacer(),
              const LanguageToggle(),
              const SizedBox(width: 12),
              _buildFreeViewsBadge(provider, lang),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                lang == 'es'
                    ? 'Lo que los coreanos realmente piensan'
                    : "What Koreans actually think",
                style: const TextStyle(
                  fontSize: 13,
                  color: KokColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreeViewsBadge(AppProvider provider, String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: provider.freeViewsRemaining > 0
            ? KokColors.success.withAlpha(20)
            : KokColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.freeViewsRemaining > 0
              ? KokColors.success.withAlpha(60)
              : KokColors.error.withAlpha(60),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_rounded,
            size: 14,
            color: provider.freeViewsRemaining > 0
                ? KokColors.success
                : KokColors.error,
          ),
          const SizedBox(width: 4),
          Text(
            '${provider.freeViewsRemaining}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: provider.freeViewsRemaining > 0
                  ? KokColors.success
                  : KokColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleList(AppProvider provider) {
    final articles = provider.filteredArticles;

    if (articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: KokColors.textMuted),
            const SizedBox(height: 12),
            Text(
              provider.language == 'es'
                  ? 'No se encontraron artículos'
                  : 'No articles found',
              style: const TextStyle(
                fontSize: 16,
                color: KokColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => provider.clearTags(),
              child: Text(
                provider.language == 'es'
                    ? 'Limpiar filtros'
                    : 'Clear filters',
                style: const TextStyle(color: KokColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadArticles(),
      color: KokColors.primary,
      backgroundColor: KokColors.surface,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          final isLocked = !provider.isArticleUnlocked(article.id) &&
              !provider.canViewFree;

          return NewsCard(
            article: article,
            isLocked: isLocked,
            onTap: () => _onArticleTap(article.id),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: KokColors.primary),
    );
  }
}
