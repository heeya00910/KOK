import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../services/content_scheduler.dart';
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
  bool _isGenerating = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runPipeline(AppProvider provider) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      await ContentScheduler().runPipeline();
      await provider.loadArticles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content generated successfully'), backgroundColor: KokColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: KokColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
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

  Future<void> _confirmDeleteArticle(AppProvider provider, String articleId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KokColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete article', style: TextStyle(color: KokColors.textPrimary, fontSize: 16)),
        content: Text(
          'Delete "$title"?',
          style: const TextStyle(color: KokColors.textSecondary, fontSize: 13),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: KokColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: KokColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.adminDeleteArticle(articleId);
    await provider.loadArticles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article deleted'), backgroundColor: KokColors.success),
      );
    }
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
              Image.asset('assets/images/kok_logo.png', height: 34, fit: BoxFit.contain),
              const Spacer(),
              if (provider.isAdmin)
                GestureDetector(
                  onTap: _isGenerating ? null : () => _runPipeline(provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isGenerating ? KokColors.textMuted.withAlpha(20) : KokColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isGenerating
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: KokColors.primary))
                        : const Icon(Icons.auto_awesome_rounded, size: 16, color: KokColors.primary),
                  ),
                ),
              if (provider.isAdmin) const SizedBox(width: 8),
              const LanguageToggle(),
              const SizedBox(width: 12),
              _buildFreeViewsBadge(provider, lang),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lang == 'es'
                ? 'LO QUE LOS COREANOS REALMENTE PIENSAN'
                : 'WHAT KOREANS ACTUALLY THINK',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: KokColors.textMuted.withAlpha(160),
              letterSpacing: 2.5,
            ),
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

          return Stack(
            children: [
              NewsCard(
                article: article,
                isLocked: isLocked,
                onTap: () => _onArticleTap(article.id),
              ),
              if (provider.isAdmin)
                Positioned(
                  top: 14,
                  right: 28,
                  child: GestureDetector(
                    onTap: () => _confirmDeleteArticle(provider, article.id, article.issueTitle(provider.language)),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 16, color: KokColors.error),
                    ),
                  ),
                ),
            ],
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
