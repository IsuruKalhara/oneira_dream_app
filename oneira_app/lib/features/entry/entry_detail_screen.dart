import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';
import '../../ui/night.dart';
import '../../widgets/interpretation_view.dart';

/// A saved dream, in the same night idiom as the rest of the app. This screen
/// is pushed OVER the shell, so it draws its own [NightCanvas] and has no
/// floating nav bar to clear — only the home indicator.
class EntryDetailScreen extends ConsumerWidget {
  final DreamEntry entry;
  const EntryDetailScreen(this.entry, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final interp = Interpretation(
      explanation: entry.explanation,
      reflection: entry.reflection,
      symbols: entry.symbolList,
      quotes: entry.quoteList,
      model: entry.model,
    );

    return Scaffold(
      backgroundColor: Ob.ink,
      body: NightCanvas(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Ob.muted),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          DateFormat.yMMMEd().format(entry.createdAt),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Ob.parchment,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(Icons.delete_outline, color: t.colorScheme.error),
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Ob.measure(
                  child: InterpretationView(
                    transcript: entry.transcript,
                    interp: interp,
                    padding: EdgeInsets.fromLTRB(
                        22, 8, 22, 24 + MediaQuery.paddingOf(context).bottom),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this dream?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(dreamRepositoryProvider).delete(entry.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
