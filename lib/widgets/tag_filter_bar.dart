import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/tags.dart';
import '../providers/app_provider.dart';

class TagFilterBar extends StatelessWidget {
  const TagFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final selected = provider.selectedTags;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            _FilterButton(
              count: selected.length,
              onTap: () => _openFilterSheet(context),
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final tag = selected.elementAt(i);
                    final display = KokTags.issueTagDisplay[tag] ?? tag;
                    return _ActiveChip(
                      label: display,
                      onRemove: () => provider.toggleTag(tag),
                    );
                  },
                ),
              ),
            ] else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    provider.language == 'es' ? 'Todos los temas' : 'All topics',
                    style: const TextStyle(fontSize: 13, color: KokColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppProvider>(),
        child: const _FilterSheet(),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _FilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasFilters = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: hasFilters
              ? const LinearGradient(colors: [KokColors.gradientStart, KokColors.gradientEnd])
              : null,
          color: hasFilters ? null : KokColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: hasFilters ? null : Border.all(color: KokColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 15,
                color: hasFilters ? Colors.white : KokColors.textSecondary),
            if (hasFilters) ...[
              const SizedBox(width: 5),
              Text('$count', style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: KokColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KokColors.primary.withAlpha(40), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: KokColors.primary)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: KokColors.primary),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filter(List<String> tags) {
    if (_search.isEmpty) return tags;
    final q = _search.toLowerCase();
    return tags.where((t) {
      final display = (KokTags.issueTagDisplay[t] ?? t).toLowerCase();
      return display.contains(q) || t.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lang = provider.language;
    final selected = provider.selectedTags;

    final filteredTopics = _filter(KokTags.issueTags);
    final filteredArtists = _filter(KokTags.artistTags);
    final filteredAgencies = _filter(KokTags.agencyTags);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: KokColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: KokColors.textMuted.withAlpha(80), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 20, color: KokColors.textPrimary),
                const SizedBox(width: 8),
                Text(lang == 'es' ? 'Filtros' : 'Filters',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: KokColors.textPrimary)),
                const Spacer(),
                if (selected.isNotEmpty)
                  GestureDetector(
                    onTap: () => provider.clearTags(),
                    child: Text(lang == 'es' ? 'Limpiar todo' : 'Clear all',
                        style: const TextStyle(fontSize: 13, color: KokColors.primary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: KokColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KokColors.border, width: 0.5),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: KokColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: KokColors.textMuted),
                  suffixIcon: _search.isNotEmpty
                      ? GestureDetector(
                          onTap: () { _searchController.clear(); setState(() => _search = ''); },
                          child: const Icon(Icons.clear_rounded, size: 18, color: KokColors.textMuted))
                      : null,
                  hintText: lang == 'es' ? 'Buscar artista, tema...' : 'Search artist, topic...',
                  hintStyle: const TextStyle(color: KokColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                if (filteredTopics.isNotEmpty) ...[
                  _sectionTitle(lang == 'es' ? 'Temas' : 'Topics'),
                  _buildGrid(filteredTopics, selected, provider, isIssue: true),
                  const SizedBox(height: 16),
                ],
                if (filteredArtists.isNotEmpty) ...[
                  _sectionTitle(lang == 'es' ? 'Artistas' : 'Artists'),
                  _buildGrid(filteredArtists, selected, provider),
                  const SizedBox(height: 16),
                ],
                if (filteredAgencies.isNotEmpty) ...[
                  _sectionTitle(lang == 'es' ? 'Agencias' : 'Agencies'),
                  _buildGrid(filteredAgencies, selected, provider),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: KokColors.border, width: 0.5)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KokColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  selected.isEmpty
                      ? (lang == 'es' ? 'Mostrar todo' : 'Show all')
                      : (lang == 'es' ? 'Aplicar (${selected.length})' : 'Apply (${selected.length})'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: KokColors.textSecondary)),
    );
  }

  Widget _buildGrid(List<String> tags, Set<String> selected, AppProvider provider, {bool isIssue = false}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final isActive = selected.contains(tag);
        final display = KokTags.issueTagDisplay[tag] ?? tag;
        final icon = isIssue ? KokTags.issueTagIcons[tag] : null;

        return GestureDetector(
          onTap: () => provider.toggleTag(tag),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: isActive
                  ? const LinearGradient(colors: [KokColors.gradientStart, KokColors.gradientEnd])
                  : null,
              color: isActive ? null : KokColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: isActive ? null : Border.all(color: KokColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActive)
                  const Padding(
                    padding: EdgeInsets.only(right: 5),
                    child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  )
                else if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(icon, size: 14, color: KokColors.textMuted),
                  ),
                Text(display, style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : KokColors.textSecondary,
                )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
