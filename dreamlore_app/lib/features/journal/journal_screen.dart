import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';
import '../entry/entry_detail_screen.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dreams = ref.watch(dreamsStreamProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: dreams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load journal.\n$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.nightlight_round,
                        size: 48, color: t.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('No dreams yet', style: t.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Log a dream when you wake and it will appear here.',
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              final symbols =
                  e.symbolList.take(3).map((s) => s.symbol).join(' · ');
              return ListTile(
                leading: e.imagePath.isEmpty
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(e.imagePath),
                            width: 48, height: 48, fit: BoxFit.cover),
                      ),
                title: Text(e.transcript,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${DateFormat.yMMMEd().add_jm().format(e.createdAt)}'
                  '${symbols.isNotEmpty ? '  ·  $symbols' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EntryDetailScreen(e)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
