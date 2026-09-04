import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';
import '../../ui/cards.dart';
import '../../ui/night.dart';
import '../../ui/scaffold.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dreams = ref.watch(dreamsStreamProvider);

    return NightScaffold(
      title: 'Insights',
      padded: false,
      child: dreams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          tint: Theme.of(context).colorScheme.error,
          title: "Couldn't read your patterns",
          body: 'Your entries are safe on this device. Reopening the app '
              'usually clears this.',
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              title: 'Nothing to see yet',
              body: 'Patterns appear here once you have a few nights logged — '
                  'the symbols that keep coming back, and how often you dream.',
            );
          }

          final counts = <String, int>{};
          for (final e in list) {
            for (final s in e.symbolList) {
              final k = s.symbol.trim();
              if (k.isEmpty) continue;
              counts.update(k, (v) => v + 1, ifAbsent: () => 1);
            }
          }
          final top = counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topN = top.take(8).toList();
          final maxCount = topN.isEmpty ? 1 : topN.first.value;

          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          final thisWeek = list.where((e) => e.createdAt.isAfter(weekAgo)).length;

          // Which of the last seven nights have an entry — Open's week strip.
          // A rhythm is legible at a glance in a way a count never is.
          final today = DateTime.now();
          final week = List.generate(7, (i) {
            final day = DateTime(today.year, today.month, today.day)
                .subtract(Duration(days: 6 - i));
            return (
              day: day,
              logged: list.any((e) =>
                  e.createdAt.year == day.year &&
                  e.createdAt.month == day.month &&
                  e.createdAt.day == day.day),
            );
          });

          return ListView(
            // The nav bar floats over the body, so its inset has to be added by
            // hand — an explicit padding opts this list out of the automatic
            // MediaQuery padding the other lists get.
            padding: EdgeInsets.fromLTRB(
                22, 0, 22, 28 + MediaQuery.paddingOf(context).bottom),
            children: [
              _WeekStrip(week: week),
              const SizedBox(height: 22),
              if (topN.isNotEmpty) ...[
                _HeroSymbol(symbol: topN.first.key, count: topN.first.value),
                const SizedBox(height: 22),
              ],
              Row(
                children: [
                  Expanded(
                      child: _Stat(
                          value: '${list.length}',
                          label: 'dreams logged',
                          seed: 1)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _Stat(
                          value: '$thisWeek', label: 'this week', seed: 2)),
                ],
              ),
              const SizedBox(height: 26),
              if (topN.isEmpty)
                const InfoCard(
                  icon: Icons.auto_awesome,
                  title: 'No recurring symbols yet',
                  body: 'Symbols surface once the same image shows up on more '
                      'than one night.',
                )
              else ...[
                const Text(
                  'RECURRING SYMBOLS',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Ob.muted,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Column(
                    children: [
                      for (final e in topN)
                        _Bar(symbol: e.key, count: e.value, max: maxCount),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final int seed;
  const _Stat({required this.value, required this.label, required this.seed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        height: 118,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: NebulaFill(seed: seed)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: Ob.parchment,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: const TextStyle(fontSize: 12.5, color: Ob.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String symbol;
  final int count;
  final int max;
  const _Bar({required this.symbol, required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '$symbol, $count ${count == 1 ? 'time' : 'times'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Ob.parchment,
                    ),
                  ),
                ),
                Text('$count',
                    style: const TextStyle(fontSize: 13, color: Ob.muted)),
              ],
            ),
            const SizedBox(height: 7),
            // Label above the bar rather than beside it — a fixed-width label
            // column clipped long symbols at large text scales.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(
                      height: 8, color: Colors.white.withValues(alpha: 0.06)),
                  FractionallySizedBox(
                    widthFactor: (count / max).clamp(0.04, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary.withValues(alpha: 0.65),
                            primary,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Seven nights, one dot each. Filled means a dream was logged.
class _WeekStrip extends StatelessWidget {
  final List<({DateTime day, bool logged})> week;
  const _WeekStrip({required this.week});

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final loggedCount = week.where((d) => d.logged).length;
    return Semantics(
      label: '$loggedCount of the last 7 nights logged',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final d in week)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _initials[d.day.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: d.logged ? Ob.parchment : Ob.muted,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.logged ? primary : Colors.transparent,
                      border: d.logged
                          ? null
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.16)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The single most recurring image, named and given the space a headline gets.
///
/// The screen used to be a list of counts; a count is data, but the symbol is
/// the thing the user is actually curious about. Naming one makes the screen
/// about them rather than about the database.
class _HeroSymbol extends StatelessWidget {
  final String symbol;
  final int count;
  const _HeroSymbol({required this.symbol, required this.count});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Your most recurring symbol is $symbol, on $count nights',
      excludeSemantics: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: NebulaFill(seed: 5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KEEPS COMING BACK',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          symbol,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Ob.serif(size: 30, height: 1.15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          count == 1
                              ? 'on one night so far'
                              : 'across $count nights',
                          style: const TextStyle(
                              fontSize: 13.5, color: Ob.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const MoonDisc(size: 62, phase: 0.78),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
