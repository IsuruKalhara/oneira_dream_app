import 'package:flutter/material.dart';

import '../record/record_screen.dart';
import '../journal/journal_screen.dart';
import '../insights/insights_screen.dart';
import '../settings/settings_screen.dart';
import '../../ui/motion.dart';
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
    NavItem(icon: Icons.mic_none, activeIcon: Icons.mic, label: 'Dream'),
    NavItem(
      icon: Icons.book_outlined,
      activeIcon: Icons.book,
      label: 'Journal',
    ),
    NavItem(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights,
      label: 'Patterns',
    ),
    NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Every page stays alive (a half-typed dream survives a detour to
            // the journal), only the active one is on stage, and the switch
            // is a short cross-fade rather than a cut. TickerMode mutes the
            // hidden pages' animations — without it the mic orb keeps
            // breathing for nobody.
            for (var i = 0; i < _pages.length; i++)
              _TabPage(
                active: i == _index,
                // Which side the page lives on relative to the current one,
                // so the motion follows the direction of travel.
                side: (i - _index).sign,
                child: TickerMode(enabled: i == _index, child: _pages[i]),
              ),
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

/// One tab's page: fades and drifts in when it becomes active, fades out when
/// it doesn't, and leaves the stage entirely once hidden so it costs nothing
/// to paint or hit-test. State is kept throughout.
class _TabPage extends StatefulWidget {
  final bool active;
  final int side;
  final Widget child;
  const _TabPage({
    required this.active,
    required this.side,
    required this.child,
  });

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> {
  late bool _staged = widget.active;

  @override
  void didUpdateWidget(_TabPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !_staged) _staged = true;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final duration = reduced ? Duration.zero : Motion.base;
    return Offstage(
      offstage: !_staged,
      child: IgnorePointer(
        ignoring: !widget.active,
        child: AnimatedOpacity(
          opacity: widget.active ? 1 : 0,
          duration: duration,
          curve: widget.active ? Motion.curve : Curves.easeIn,
          onEnd: () {
            if (!widget.active && mounted) setState(() => _staged = false);
          },
          child: AnimatedSlide(
            // Material's shared-axis X: a short lateral travel, never a
            // full-width swipe, so it reads as "next" not "elsewhere".
            offset: widget.active ? Offset.zero : Offset(0.06 * widget.side, 0),
            duration: duration,
            curve: Motion.curve,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
