import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/dream_image_card.dart';
import '../../widgets/interpretation_view.dart';
import '../../widgets/safety_view.dart';
import '../paywall/paywall_screen.dart';
import '../paywall/plus_upsell_sheet.dart';
import 'record_controller.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});
  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordControllerProvider);
    final ctl = ref.read(recordControllerProvider.notifier);

    // Keep the text field in sync with live transcription without fighting edits.
    ref.listen(recordControllerProvider, (prev, next) {
      if (next.imageNeedsPlus && !(prev?.imageNeedsPlus ?? false)) {
        ref.read(entitlementProvider.notifier).refresh();
        PlusUpsellSheet.show(context);
      }
      if (next.transcript != _text.text) {
        _text.value = TextEditingValue(
          text: next.transcript,
          selection: TextSelection.collapsed(offset: next.transcript.length),
        );
      }
    });

    final Widget body = switch (state.status) {
      RecordStatus.interpreting => _busy(context),
      RecordStatus.done => _done(context, state, ctl),
      RecordStatus.safety => SafetyView(onDismiss: ctl.reset),
      RecordStatus.error => _error(context, state, ctl),
      _ => _capture(context, state, ctl),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log a dream'),
        actions: [
          if (state.status == RecordStatus.done ||
              state.status == RecordStatus.error)
            IconButton(
              tooltip: 'New dream',
              onPressed: ctl.reset,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _capture(BuildContext context, RecordState state, RecordController ctl) {
    final t = Theme.of(context);
    final listening = state.status == RecordStatus.listening;
    final canInterpret = state.transcript.trim().isNotEmpty && !listening;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _quotaBanner(context),
          const Spacer(),
          GestureDetector(
            onTap: ctl.toggleListening,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening
                    ? t.colorScheme.error
                    : t.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: (listening ? t.colorScheme.error : t.colorScheme.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 56, color: t.colorScheme.onPrimary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            listening ? 'Listening… tap to stop' : 'Tap and tell me your dream',
            style: t.textTheme.titleMedium,
          ),
          const Spacer(),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            onChanged: ctl.editTranscript,
            decoration: const InputDecoration(
              hintText: 'Your dream will appear here — you can edit it too.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canInterpret ? ctl.interpret : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Interpret'),
          ),
        ],
      ),
    );
  }

  Widget _quotaBanner(BuildContext context) {
    final t = Theme.of(context);
    final quota = ref.watch(quotaProvider).asData?.value;
    if (quota == null || quota.isPaid) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${quota.dayRemaining} of ${quota.dayLimit} free interpretations left today',
              style: t.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen())),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Widget _busy(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Reading your dream…',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );

  Widget _done(BuildContext context, RecordState state, RecordController ctl) {
    final isPaid = ref.watch(entitlementProvider);
    return Column(
      children: [
        Expanded(
          child: InterpretationView(
            transcript: state.transcript,
            interp: state.interpretation!,
            picture: DreamImageCard(
              status: state.imageStatus,
              locked: !isPaid,
              bytes: state.imageBytes,
              error: state.imageError,
              // Free users get the offer, not a request that would only 403.
              onGenerate: isPaid
                  ? ctl.imagine
                  : () => PlusUpsellSheet.show(context),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: ctl.reset,
                  child: const Text('New dream'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save'),
                  onPressed: () async {
                    await ctl.save();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to your journal')),
                    );
                    ctl.reset();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _error(BuildContext context, RecordState state, RecordController ctl) {
    final t = Theme.of(context);
    final q = state.quotaError;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(q != null ? Icons.lock_clock : Icons.error_outline,
              size: 44, color: t.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            q != null
                ? "You've used all your ${q.reason == 'monthly' ? 'monthly' : 'daily'} interpretations"
                : 'Something went wrong',
            style: t.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            q != null
                ? (q.resetsAt != null
                    ? 'Resets ${_friendly(q.resetsAt!)}. Your dream is still here — save it and come back.'
                    : 'Your dream is still saved here — come back when it resets.')
                : (state.error ?? 'Please try again.'),
            style: t.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (q != null && q.upgrade)
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen())),
              child: const Text('Upgrade for more'),
            )
          else if (q == null)
            FilledButton(
                onPressed: ctl.interpret, child: const Text('Try again')),
          TextButton(onPressed: ctl.reset, child: const Text('Start over')),
        ],
      ),
    );
  }

  String _friendly(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final tomorrow = local.day != now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return tomorrow ? 'tomorrow at $hh:$mm' : 'at $hh:$mm';
  }
}
