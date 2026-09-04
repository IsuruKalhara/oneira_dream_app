import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/api/dream_api.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/dream_image_card.dart';
import '../../widgets/interpretation_view.dart';
import '../paywall/plus_upsell_sheet.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  final DreamEntry entry;
  const EntryDetailScreen(this.entry, {super.key});

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  // A saved dream can be painted later. Once it is, the picture is written
  // straight into the entry — there is no separate "save" step here because
  // the dream is already in the journal.
  late String _imagePath = widget.entry.imagePath;
  Uint8List? _bytes;
  DreamImageStatus _status = DreamImageStatus.idle;
  String? _error;

  Future<void> _imagine() async {
    final e = widget.entry;
    setState(() {
      _status = DreamImageStatus.generating;
      _error = null;
    });
    try {
      final bytes = await ref
          .read(dreamApiProvider)
          .imagine(e.transcript, symbols: e.symbolList);
      final store = ref.read(imageStoreProvider);
      await store.delete(_imagePath);
      final path = await store.save(e.id, bytes);
      await ref.read(dreamRepositoryProvider).setImagePath(e.id, path);
      ref.invalidate(quotaProvider);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _imagePath = path;
        _status = DreamImageStatus.ready;
      });
    } on PlusRequiredException {
      if (!mounted) return;
      setState(() => _status = DreamImageStatus.idle);
      ref.read(entitlementProvider.notifier).refresh();
      PlusUpsellSheet.show(context);
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = DreamImageStatus.error;
        _error = e.reason == 'monthly'
            ? "You've painted all your dreams for this month."
            : "You've painted all your dreams for today.";
      });
    } catch (_) {
      if (mounted) setState(() => _status = DreamImageStatus.error);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this dream?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(imageStoreProvider).delete(_imagePath);
    await ref.read(dreamRepositoryProvider).delete(widget.entry.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isPaid = ref.watch(entitlementProvider);
    final interp = Interpretation(
      explanation: entry.explanation,
      reflection: entry.reflection,
      symbols: entry.symbolList,
      quotes: entry.quoteList,
      model: entry.model,
    );
    final hasImage = _bytes != null || _imagePath.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMEd().format(entry.createdAt)),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: InterpretationView(
        transcript: entry.transcript,
        interp: interp,
        picture: DreamImageCard(
          status: _status == DreamImageStatus.idle && hasImage
              ? DreamImageStatus.ready
              : _status,
          locked: !isPaid,
          bytes: _bytes,
          path: _imagePath,
          error: _error,
          onGenerate:
              isPaid ? _imagine : () => PlusUpsellSheet.show(context),
        ),
      ),
    );
  }
}
