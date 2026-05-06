import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/tags.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../widgets/language_toggle.dart';
import 'legal_page.dart';
import 'login_page.dart';

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
            SliverToBoxAdapter(child: _buildAccountSection(context, provider, lang)),
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
          if (profile.favoriteTags.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildRepresentativeFandomSelector(provider, lang, profile),
          ],
        ],
      ),
    );
  }

  Widget _buildRepresentativeFandomSelector(
    AppProvider provider,
    String lang,
    UserProfile profile,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KokColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KokColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, size: 16, color: KokColors.primary),
              const SizedBox(width: 6),
              Text(
                lang == 'es' ? 'Badge de comentario' : 'Comment badge',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: KokColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                lang == 'es'
                    ? 'Se muestra junto a tu nombre'
                    : 'Shown next to your name',
                style: const TextStyle(fontSize: 10, color: KokColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.favoriteTags.map((tag) {
              final isRep = profile.representativeFandom == tag;
              return GestureDetector(
                onTap: () => provider.updateRepresentativeFandom(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isRep
                        ? KokColors.primary.withAlpha(20)
                        : KokColors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isRep
                          ? KokColors.primary.withAlpha(120)
                          : KokColors.border,
                      width: isRep ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRep) ...[
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: KokColors.primary),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isRep ? FontWeight.w700 : FontWeight.w500,
                          color: isRep
                              ? KokColors.primary
                              : KokColors.textSecondary,
                        ),
                      ),
                    ],
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
                    if (comment.isEdited) ...[
                      const SizedBox(width: 4),
                      Text(
                        lang == 'es' ? '(editado)' : '(edited)',
                        style: const TextStyle(fontSize: 10, color: KokColors.textMuted, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showEditCommentDialog(context, provider, comment, lang),
                      child: const Icon(Icons.edit_outlined, size: 15, color: KokColors.textMuted),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _confirmDeleteComment(context, provider, comment, lang),
                      child: const Icon(Icons.delete_outline_rounded, size: 15, color: KokColors.textMuted),
                    ),
                    const SizedBox(width: 12),
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

  void _showEditCommentDialog(BuildContext context, AppProvider provider, comment, String lang) {
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
                provider.editComment(comment.articleId, comment.id, text);
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

  void _confirmDeleteComment(BuildContext context, AppProvider provider, comment, String lang) {
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
              provider.deleteComment(comment.articleId, comment.id);
              Navigator.pop(ctx);
            },
            child: Text(lang == 'es' ? 'Eliminar' : 'Delete',
                style: const TextStyle(color: KokColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, AppProvider provider, String lang) {
    final email = AuthService().currentUser?.email ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: KokColors.border, height: 1),
          const SizedBox(height: 20),
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 16, color: KokColors.textMuted),
                  const SizedBox(width: 8),
                  Flexible(child: Text(email, style: const TextStyle(fontSize: 13, color: KokColors.textMuted), overflow: TextOverflow.ellipsis)),
                  if (provider.isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KokColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Admin',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: KokColors.primary)),
                    ),
                  ],
                ],
              ),
            ),
          _buildAccountTile(
            icon: Icons.description_outlined,
            label: lang == 'es' ? 'Terminos de Servicio' : 'Terms of Service',
            color: KokColors.textSecondary,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LegalPage(type: LegalType.terms))),
          ),
          const SizedBox(height: 8),
          _buildAccountTile(
            icon: Icons.shield_outlined,
            label: lang == 'es' ? 'Politica de Privacidad' : 'Privacy Policy',
            color: KokColors.textSecondary,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LegalPage(type: LegalType.privacy))),
          ),
          const SizedBox(height: 8),
          _buildAccountTile(
            icon: Icons.groups_outlined,
            label: lang == 'es' ? 'Normas de la Comunidad' : 'Community Guidelines',
            color: KokColors.textSecondary,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LegalPage(type: LegalType.community))),
          ),
          const SizedBox(height: 16),
          _buildAccountTile(
            icon: Icons.logout_rounded,
            label: lang == 'es' ? 'Cerrar sesion' : 'Log out',
            color: KokColors.textSecondary,
            onTap: () => _confirmLogout(context, lang),
          ),
          const SizedBox(height: 8),
          _buildAccountTile(
            icon: Icons.person_off_rounded,
            label: lang == 'es' ? 'Eliminar cuenta' : 'Delete account',
            color: KokColors.error,
            onTap: () => _confirmDeleteAccount(context, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(25), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 18, color: color.withAlpha(120)),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KokColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lang == 'es' ? 'Cerrar sesion' : 'Log out',
          style: const TextStyle(color: KokColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          lang == 'es' ? 'Seguro que quieres cerrar sesion?' : 'Are you sure you want to log out?',
          style: const TextStyle(color: KokColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'es' ? 'Cancelar' : 'Cancel',
                style: const TextStyle(color: KokColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              }
            },
            child: Text(lang == 'es' ? 'Salir' : 'Log out',
                style: const TextStyle(color: KokColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KokColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lang == 'es' ? 'Eliminar cuenta' : 'Delete account',
          style: const TextStyle(color: KokColors.error, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          lang == 'es'
              ? 'Tu cuenta y todos tus datos seran eliminados permanentemente. Esta accion no se puede deshacer.'
              : 'Your account and all your data will be permanently deleted. This cannot be undone.',
          style: const TextStyle(color: KokColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'es' ? 'Cancelar' : 'Cancel',
                style: const TextStyle(color: KokColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService().signOut();
              } catch (_) {}
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              }
            },
            child: Text(lang == 'es' ? 'Eliminar' : 'Delete',
                style: const TextStyle(color: KokColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
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
