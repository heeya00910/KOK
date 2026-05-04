import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/tags.dart';
import '../providers/app_provider.dart';

class TagFilterBar extends StatefulWidget {
  const TagFilterBar({super.key});

  @override
  State<TagFilterBar> createState() => _TagFilterBarState();
}

class _TagFilterBarState extends State<TagFilterBar> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            labelColor: KokColors.primary,
            unselectedLabelColor: KokColors.textMuted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            indicatorColor: KokColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Topics'),
              Tab(text: 'Artists'),
              Tab(text: 'Agencies'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildChipRow(KokTags.issueTags, provider, isIssue: true),
              _buildChipRow(KokTags.artistTags, provider),
              _buildChipRow(KokTags.agencyTags, provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChipRow(List<String> tags, AppProvider provider, {bool isIssue = false}) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: tags.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          final isActive = provider.selectedTags.isEmpty;
          return GestureDetector(
            onTap: () => provider.clearTags(),
            child: _buildAllChip(isActive),
          );
        }

        final tag = tags[index - 1];
        final isActive = provider.selectedTags.contains(tag);

        if (isIssue) {
          return GestureDetector(
            onTap: () => provider.toggleTag(tag),
            child: _buildIssueChip(tag, isActive),
          );
        }

        return GestureDetector(
          onTap: () => provider.toggleTag(tag),
          child: _buildChip(tag, isActive),
        );
      },
    );
  }

  Widget _buildAllChip(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(colors: [KokColors.gradientStart, KokColors.gradientEnd])
            : null,
        color: isActive ? null : KokColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: isActive ? null : Border.all(color: KokColors.border, width: 0.5),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, size: 13,
                color: isActive ? Colors.white : KokColors.textSecondary),
            const SizedBox(width: 5),
            Text('All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : KokColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueChip(String tag, bool isActive) {
    final icon = KokTags.issueTagIcons[tag] ?? Icons.tag_rounded;
    final display = KokTags.issueTagDisplay[tag] ?? tag;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(colors: [KokColors.gradientStart, KokColors.gradientEnd])
            : null,
        color: isActive ? null : KokColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: isActive ? null : Border.all(color: KokColors.border, width: 0.5),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? Colors.white : KokColors.textSecondary),
            const SizedBox(width: 5),
            Text(display,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : KokColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [KokColors.gradientStart, KokColors.gradientEnd],
              )
            : null,
        color: isActive ? null : KokColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: isActive ? null : Border.all(color: KokColors.border, width: 0.5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : KokColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
