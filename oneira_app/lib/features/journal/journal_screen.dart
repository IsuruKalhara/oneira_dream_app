import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';
import '../../ui/night.dart';
import '../../ui/scaffold.dart';
import '../entry/entry_detail_screen.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dreams = ref.watch(dreamsStreamProvider);

    return NightScaffold(
      title: 'Journal',
      padded: false,
      child: dreams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          tint: Theme.of(context).colorScheme.error,
          title: "Couldn't open your journal",
          body: 'Your entries are safe on this device. Reopening the app '
              'usually clears this.',
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.nightlight_round,
              title: 'No dreams yet',
              body: 'Log one when you wake and it will appear here — along '
                  'with the symbols it shares with the nights after it.',
            );
          }
          // Flatten into headers + entries so the journal reads as a
          // timeline rather than an undifferentiated stack. A bare list of
          // rows tells you what you wrote; grouping tells you when you were
          // dreaming, which is the thing worth coming back for.
          final rows = <Object>[];
          String? current;
          for (final e in list) {
            final label = _groupLabel(e.createdAt);
            if (label != current) {
              current = label;
              rows.add(label);
            }
            rows.add(e);
          }

          return ListView.builder(
            // Explicit padding drops the extendBody inset — add the nav-bar
            // clearance back or the newest entry hides under the capsule.
            padding: EdgeInsets.fromLTRB(
                22, 0, 22, 28 + MediaQuery.paddingOf(context).bottom),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              if (row is String) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(2, i == 0 ? 0 : 18, 2, 12),
                  child: Text(
                    row.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                      color: Ob.muted,
                    ),
                  ),
                );
              }
              return _EntryCard(entry: row as DreamEntry);
            },
          );
        },
      ),
    );
  }
}

/// Recent nights get relative names; older ones fall back to the month, which
/// is how people actually remember when they dreamt something.
String _groupLabel(DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final delta = today.difference(day).inDays;
  if (delta <= 0) return 'Today';
  if (delta == 1) return 'Yesterday';
  if (delta < 7) return 'Earlier this week';
  if (delta < 30) return 'Earlier this month';
  return DateFormat.yMMMM().format(when);
}

class _EntryCard extends StatelessWidget {
  final DreamEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final symbols = entry.symbolList.take(3).map((s) => s.symbol).toList();
    final date = DateFormat.yMMMEd().add_jm().format(entry.createdAt);
    final short = DateFormat.jm().format(entry.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: '$date. ${entry.transcript}',
        excludeSemantics: true,
        child: Material(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EntryDetailScreen(entry)),
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    short.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                      color: Ob.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.transcript,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.45,
                      color: Ob.parchment,
                    ),
                  ),
                  if (symbols.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in symbols)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
