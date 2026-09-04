import 'package:flutter/material.dart';

import 'night.dart';

/// Page chrome for the main shell, in the same language as onboarding: no
/// Material [AppBar], a bold sans title on the ambient night ground, and the
/// content measure capped so it stays readable on tablets.
///
/// The [NightCanvas] lives once in `MainShell` rather than here — four pages
/// each running their own starfield would tick four animation controllers for
/// one visible result.
class NightScaffold extends StatelessWidget {
  final String title;

  /// Optional trailing control, rendered level with the title.
  final Widget? action;
  final Widget child;

  /// Set false when [child] is itself a scroll view that should run to the
  /// top edge under the title.
  final bool padded;

  const NightScaffold({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(22, 12, 22, padded ? 18 : 12),
              child: Ob.measure(
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: Ob.parchment,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                    ?action,
                  ],
                ),
              ),
            ),
            Expanded(child: Ob.measure(child: child)),
          ],
        ),
      ),
    );
  }
}

/// Centred empty state: an orb, a bold line, a quiet line, and optionally one
/// action. Errors and empties are directions, not moods — each says what to do
/// next rather than only what is missing.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final Color? tint;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Theme.of(context).colorScheme.primary;
    return Center(
      child: SingleChildScrollView(
        // When the state overflows (large text scales), its action button must
        // still scroll clear of the floating nav capsule.
        padding: EdgeInsets.fromLTRB(
            32, 24, 32, 40 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Orb(size: 92, color: color, icon: icon),
            const SizedBox(height: 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: Ob.parchment,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: Ob.muted,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 26),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
