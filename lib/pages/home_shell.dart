import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'feed_page.dart';
import 'chart_page.dart';
import 'my_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _pages = const [
    FeedPage(),
    ChartPage(),
    MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: KokColors.border, width: 0.5),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: KokColors.surface,
          indicatorColor: KokColors.primary.withAlpha(25),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.dynamic_feed_rounded,
                color: _currentIndex == 0 ? KokColors.primary : KokColors.textMuted,
              ),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.leaderboard_rounded,
                color: _currentIndex == 1 ? KokColors.primary : KokColors.textMuted,
              ),
              label: 'Chart',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_rounded,
                color: _currentIndex == 2 ? KokColors.primary : KokColors.textMuted,
              ),
              label: 'My',
            ),
          ],
        ),
      ),
    );
  }
}
