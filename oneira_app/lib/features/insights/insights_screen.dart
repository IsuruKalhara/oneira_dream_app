import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dreams = ref.watch(dreamsStreamProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: dreams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load insights.\n$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Patterns appear here as you log more dreams — the symbols that recur, and how often you dream.',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyMedium,
                ),
              ),
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _stat(t, '${list.length}', 'dreams logged')),
                  const SizedBox(width: 12),
                  Expanded(child: _stat(t, '$thisWeek', 'this week')),
                ],
              ),
              const SizedBox(height: 24),
              if (topN.isNotEmpty) ...[
                Text('Recurring symbols', style: t.textTheme.titleMedium),
                const SizedBox(height: 12),
                ...topN.map((e) => _bar(t, e.key, e.value, maxCount)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _stat(ThemeData t, String value, String label) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Text(value,
                  style: t.textTheme.headlineMedium
                      ?.copyWith(color: t.colorScheme.primary)),
              const SizedBox(height: 4),
              Text(label, style: t.textTheme.bodySmall),
            ],
          ),
        ),
      );

  Widget _bar(ThemeData t, String symbol, int count, int max) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 104,
              child: Text(symbol,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodyMedium),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: t.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (count / max).clamp(0.05, 1.0),
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 28,
              child: Text('$count',
                  textAlign: TextAlign.right, style: t.textTheme.bodyMedium),
            ),
          ],
        ),
      );
}
