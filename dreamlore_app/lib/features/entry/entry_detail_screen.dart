import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors.dart';
import '../../data/api/dream_api.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';
import '../../services/share_card.dart';
import '../../ui/night.dart';
import '../../widgets/dream_image_card.dart';
import '../../widgets/interpretation_view.dart';
import '../paywall/plus_upsell_sheet.dart';

/// A saved dream, in the same night idiom as the rest of the app. This screen
/// is pushed OVER the shell, so it draws its own [NightCanvas] and has no
/// floating nav bar to clear — only the home indicator.
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
      // Clears the current file and any orphan from an interrupted repaint.
      await store.deleteAllFor(e.id);
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
    } catch (e) {
      if (!mounted) return;
      final f = Friendly.of(e);
      setState(() {
        _status = DreamImageStatus.error;
        _error = f.offline
            ? "You're offline — paint it when you're back."
            : "Couldn't paint this one. Try again?";
      });
    }
  }

  Future<void> _share() async {
    final bytes =
        _bytes ??
        (_imagePath.isNotEmpty ? await File(_imagePath).readAsBytes() : null);
    if (bytes == null || !mounted) return;
    await ShareCard.share(
      context: context,
      imageBytes: bytes,
      dream: widget.entry.transcript,
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this dream?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // The picture is a file beside the row, so it goes with it.
    await ref.read(imageStoreProvider).delete(_imagePath);
    await ref.read(dreamRepositoryProvider).delete(widget.entry.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
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
                    if (hasImage)
                      IconButton(
                        tooltip: 'Share',
                        icon: const Icon(Icons.ios_share, color: Ob.muted),
                        onPressed: _share,
                      ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(
                        Icons.delete_outline,
                        color: t.colorScheme.error,
                      ),
                      onPressed: _confirmDelete,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Ob.measure(
                  child: InterpretationView(
                    transcript: entry.transcript,
                    interp: interp,
                    animate: false,
                    padding: EdgeInsets.fromLTRB(
                      22,
                      8,
                      22,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    picture: DreamImageCard(
                      status: _status == DreamImageStatus.idle && hasImage
                          ? DreamImageStatus.ready
                          : _status,
                      locked: !isPaid,
                      bytes: _bytes,
                      path: _imagePath,
                      error: _error,
                      onGenerate: isPaid
                          ? _imagine
                          : () => PlusUpsellSheet.show(context),
                      onShare: hasImage ? _share : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
