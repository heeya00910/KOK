import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/tags.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';
import '../widgets/language_toggle.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lang = provider.language;
    final profile = provider.profile;

    return Scaffold(
      backgroundColor: KokColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, lang)),
            SliverToBoxAdapter(child: _buildProfileCard(context, provider, lang, profile)),
            SliverToBoxAdapter(child: _buildFavoriteTagsSection(context, provider, lang, profile)),
            SliverToBoxAdapter(child: _buildMyCommentsHeader(lang, provider)),
            _buildMyCommentsList(provider, lang),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(
            lang == 'es' ? 'Mi Perfil' : 'My Page',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: KokColors.textPrimary,
            ),
          ),
          const Spacer(),
          const LanguageToggle(),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    AppProvider provider,
    String lang,
    UserProfile profile,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            KokColors.primary.withAlpha(15),
            KokColors.accent.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KokColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [KokColors.gradientStart, KokColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    profile.nickname.isNotEmpty
                        ? profile.nickname[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.nickname.isNotEmpty
                          ? profile.nickname
                          : (lang == 'es' ? 'Toca para configurar' : 'Tap to set up'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: profile.nickname.isNotEmpty
                            ? KokColors.textPrimary
                            : KokColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.nationality.isNotEmpty
                          ? profile.nationality
                          : (lang == 'es' ? 'Sin país configurado' : 'No country set'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: KokColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEditButton(
                  icon: Icons.edit_rounded,
                  label: lang == 'es' ? 'Nickname' : 'Nickname',
                  onTap: () => _showNicknameDialog(context, provider, lang),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildEditButton(
                  icon: Icons.flag_rounded,
                  label: lang == 'es' ? 'País' : 'Country',
                  onTap: () => _showNationalityPicker(context, provider, lang),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: KokColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KokColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: KokColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KokColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteTagsSection(
    BuildContext context,
    AppProvider provider,
    String lang,
    UserProfile profile,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [KokColors.gradientStart, KokColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.star_rounded, size: 18, color: KokColors.primary),
              const SizedBox(width: 6),
              Text(
                lang == 'es' ? 'Mis Favoritos' : 'My Favorites',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: KokColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lang == 'es'
                ? 'Selecciona artistas o agencias que sigues'
                : 'Select artists or agencies you follow',
            style: const TextStyle(fontSize: 13, color: KokColors.textMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: KokTags.allArtistAndAgency.map((tag) {
              final isSelected = profile.favoriteTags.contains(tag);
              return GestureDetector(
                onTap: () => provider.toggleFavoriteTag(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [KokColors.gradientStart, KokColors.gradientEnd],
                          )
                        : null,
                    color: isSelected ? null : KokColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(color: KokColors.border, width: 0.5),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : KokColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCommentsHeader(String lang, AppProvider provider) {
    final count = provider.myComments.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [KokColors.gradientStart, KokColors.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: KokColors.primary),
          const SizedBox(width: 6),
          Text(
            lang == 'es' ? 'Mis Comentarios' : 'My Comments',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: KokColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: KokColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                color: KokColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCommentsList(AppProvider provider, String lang) {
    final comments = provider.myComments;

    if (comments.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: KokColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KokColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: KokColors.textMuted),
              const SizedBox(height: 12),
              Text(
                provider.profile.nickname.isEmpty
                    ? (lang == 'es'
                        ? 'Configura tu nickname para comentar'
                        : 'Set up your nickname to comment')
                    : (lang == 'es'
                        ? 'Aún no has comentado'
                        : 'No comments yet'),
                style: const TextStyle(
                  fontSize: 14,
                  color: KokColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final comment = comments[index];
          final article = provider.articles
              .where((a) => a.id == comment.articleId)
              .firstOrNull;

          return Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KokColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KokColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article != null)
                  Text(
                    article.issueTitle(lang),
                    style: const TextStyle(
                      fontSize: 12,
                      color: KokColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (article != null) const SizedBox(height: 8),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: KokColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: KokColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.thumb_up_alt_rounded,
                        size: 13, color: KokColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.likes}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KokColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        childCount: comments.length,
      ),
    );
  }

  void _showNicknameDialog(BuildContext context, AppProvider provider, String lang) {
    final controller = TextEditingController(text: provider.profile.nickname);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KokColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang == 'es' ? 'Tu Nickname' : 'Your Nickname',
          style: const TextStyle(color: KokColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          maxLength: 20,
          style: const TextStyle(color: KokColors.textPrimary),
          decoration: InputDecoration(
            hintText: lang == 'es' ? 'Ingresa tu nickname' : 'Enter your nickname',
            hintStyle: const TextStyle(color: KokColors.textMuted),
            filled: true,
            fillColor: KokColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            counterStyle: const TextStyle(color: KokColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              lang == 'es' ? 'Cancelar' : 'Cancel',
              style: const TextStyle(color: KokColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.updateNickname(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text(
              lang == 'es' ? 'Guardar' : 'Save',
              style: const TextStyle(color: KokColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showNationalityPicker(BuildContext context, AppProvider provider, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: KokColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KokColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                lang == 'es' ? 'Selecciona tu país' : 'Select your country',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: KokColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: UserProfile.nationalities.length,
                itemBuilder: (ctx, index) {
                  final country = UserProfile.nationalities[index];
                  final isSelected = provider.profile.nationality == country;
                  return ListTile(
                    title: Text(
                      country,
                      style: TextStyle(
                        color: isSelected ? KokColors.primary : KokColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: KokColors.primary, size: 22)
                        : null,
                    onTap: () {
                      provider.updateNationality(country);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
