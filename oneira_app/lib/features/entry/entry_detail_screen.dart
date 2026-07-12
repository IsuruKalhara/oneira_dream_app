import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/interpretation_view.dart';

class EntryDetailScreen extends ConsumerWidget {
  final DreamEntry entry;
  const EntryDetailScreen(this.entry, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interp = Interpretation(
      explanation: entry.explanation,
      reflection: entry.reflection,
      symbols: entry.symbolList,
      quotes: entry.quoteList,
      model: entry.model,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMEd().format(entry.createdAt)),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
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
            },
          ),
        ],
      ),
      body: InterpretationView(transcript: entry.transcript, interp: interp),
    );
  }
}
