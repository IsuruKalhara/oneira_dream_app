import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/palette.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Floating capsule navigation, in the same night idiom as onboarding.
///
/// Replaces the stock Material [NavigationBar], which sat as an opaque bar
/// welded to the bottom edge and shared no visual language with the rest of
/// the app. This one floats clear of the content, blurs what passes beneath
/// it, and moves a lit pill between destinations instead of snapping.
///
/// Deliberately not a stack of new ideas: it reuses the palette, the hairline
/// rule, and the indigo accent that already exist elsewhere.
class OneiraNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<NavItem> items;

  const OneiraNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
  });

  static const _height = 66.0;
  static const _radius = 33.0;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: _height,
              decoration: BoxDecoration(
                color: Palette.inkDeep.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: Palette.rule),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / items.length;
                  return Stack(
                    children: [
                      // The lit pill. One moving element rather than four
                      // independently animating icons.
                      AnimatedPositioned(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 340),
                        curve: Curves.easeOutCubic,
                        left: slot * index + 6,
                        top: 6,
                        width: slot - 12,
                        height: _height - 12 - 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(_radius),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Expanded(
                              child: _NavButton(
                                item: items[i],
                                selected: i == index,
                                reduceMotion: reduceMotion,
                                onTap: () {
                                  if (i == index) return;
                                  HapticFeedback.selectionClick();
                                  onSelect(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Palette.parchment : Palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              // A small lift on selection — enough to feel responsive to the
              // tap, not enough to be a bounce.
              scale: selected ? 1.0 : 0.92,
              duration:
                  reduceMotion ? Duration.zero : const Duration(milliseconds: 340),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration:
                  reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
              style: TextStyle(
                fontSize: 10.5,
                height: 1,
                letterSpacing: selected ? 0.6 : 0.2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
