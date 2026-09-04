import 'package:flutter/material.dart';

import '../record/record_screen.dart';
import '../journal/journal_screen.dart';
import '../insights/insights_screen.dart';
import '../settings/settings_screen.dart';
import '../../ui/night.dart';
import 'dreamlore_nav_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    RecordScreen(),
    JournalScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  static const _items = [
    NavItem(icon: Icons.mic_none, activeIcon: Icons.mic, label: 'Record'),
    NavItem(
        icon: Icons.book_outlined, activeIcon: Icons.book, label: 'Journal'),
    NavItem(
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights,
        label: 'Insights'),
    NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ob.ink,
      // The bar floats, so content runs underneath it and blurs through.
      extendBody: true,
      // One ambient canvas for the whole shell — the pages are transparent, so
      // four starfields aren't ticking four controllers for one visible result.
      body: NightCanvas(
        child: IndexedStack(
          index: _index,
          children: [
            // IndexedStack keeps hidden children alive but does not mute their
            // tickers — without TickerMode the mic orb keeps animating while
            // the user sits on other tabs, burning CPU for invisible frames.
            for (var i = 0; i < _pages.length; i++)
              TickerMode(enabled: i == _index, child: _pages[i]),
          ],
        ),
      ),
      bottomNavigationBar: DreamloreNavBar(
        index: _index,
        items: _items,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}
