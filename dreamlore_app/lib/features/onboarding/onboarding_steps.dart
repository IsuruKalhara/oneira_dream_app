import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../ui/cards.dart';
import 'onboarding_controller.dart';
import '../../ui/night.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared
// ─────────────────────────────────────────────────────────────────────────────

/// Step layout: centres short content, scrolls tall content, caps the measure
/// on wide screens, and owns the entrance animation so every step arrives the
/// same way.
class StepScroll extends StatelessWidget {
  final List<Widget> children;

  /// True when this page is the one on screen. PageView builds neighbours
  /// ahead of time, so without this the entrance plays out of sight.
  final bool active;

  const StepScroll({super.key, required this.children, this.active = true});

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(22, 8, 22, 18);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - pad.vertical,
          ),
          child: Ob.measure(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stagger(
                  active: active,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 · Welcome — bento grid
// ─────────────────────────────────────────────────────────────────────────────

class WelcomeStep extends StatelessWidget {
  final VoidCallback onShowLegal;
  final bool active;
  const WelcomeStep({super.key, required this.onShowLegal, this.active = true});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return StepScroll(
      active: active,
      children: [
        const BigTitle('Tell your dream.\nWe read the books.'),
        const SizedBox(height: 12),
        const Sub(
          'Say it when you wake. We look it up in real dream books '
          'and show you the lines.',
        ),
        const SizedBox(height: 26),
        BentoGrid(
          topLeft: BentoCard(
            height: 132,
            seed: 1,
            semanticsLabel: 'Speak it. Transcribed on your phone as you talk.',
            label: const PillLabel(icon: Icons.mic_none, text: 'Speak it'),
            labelAlignment: Alignment.topLeft,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Orb(
                  size: 66,
                  color: primary,
                  icon: Icons.mic_none_rounded,
                ),
              ),
            ),
          ),
          bottomLeft: BentoCard(
            height: 200,
            seed: 2,
            semanticsLabel:
                'Night after night. Recurring symbols surface over time.',
            label: const PillLabel(
              icon: Icons.nightlight_round,
              text: 'Recurring',
            ),
            labelAlignment: Alignment.bottomLeft,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(10, 12, 10, 46),
              child: MoonCluster(),
            ),
          ),
          topRight: BentoCard(
            height: 200,
            seed: 3,
            semanticsLabel:
                'Three public-domain books: Freud twice, and Miller.',
            label: const PillLabel(
              icon: Icons.menu_book_outlined,
              text: 'Three books',
            ),
            labelAlignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final t in const [
                    'The Interpretation of Dreams',
                    'Dream Psychology',
                    'Ten Thousand Dreams Interpreted',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        t,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // Serif kept for actual book titles only — that's
                        // typographic convention, not decoration.
                        style: Ob.serif(
                          size: 13.5,
                          style: FontStyle.italic,
                          height: 1.22,
                          color: Ob.parchment.withValues(alpha: 0.86),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          bottomRight: BentoCard(
            height: 132,
            seed: 4,
            semanticsLabel: 'Private. Your journal stays on this device.',
            label: const PillLabel(icon: Icons.lock_outline, text: 'Private'),
            labelAlignment: Alignment.topLeft,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Orb(size: 66, color: primary, icon: Icons.lock_outline),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        // Required in onboarding by the App Review notes in docs/STORE-LISTING.md.
        const Text(
          'For reflection and journaling. Not medical, psychological, or '
          'predictive advice.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, height: 1.45, color: Ob.muted),
        ),
        Center(
          child: TextButton(
            onPressed: onShowLegal,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Privacy Policy · Terms of Use',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 · Intent
// ─────────────────────────────────────────────────────────────────────────────

/// Wording avoids claiming a dream *means* something factual — see
/// docs/STORE-LISTING.md "Words to AVOID".
const _intentLabels = <DreamIntent, String>{
  DreamIntent.recall: 'Remember my dreams before they fade',
  DreamIntent.recurring: 'Make sense of a dream that keeps returning',
  DreamIntent.patterns: 'Notice patterns over time',
  DreamIntent.curiosity: 'Curiosity — I just find dreams interesting',
};

class IntentStep extends StatelessWidget {
  final DreamIntent? selected;
  final ValueChanged<DreamIntent> onSelect;
  final bool active;

  const IntentStep({
    super.key,
    required this.selected,
    required this.onSelect,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    return StepScroll(
      active: active,
      children: [
        const BigTitle('What brings\nyou here?'),
        const SizedBox(height: 12),
        const Sub('This only changes how Dreamlore greets you in the morning.'),
        const SizedBox(height: 26),
        for (final entry in _intentLabels.entries)
          OptionCard(
            label: entry.value,
            selected: selected == entry.key,
            onTap: () => onSelect(entry.key),
          ),
        const SizedBox(height: 14),
        // Moonly's reassurance block — a soft landing for "I don't know".
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            children: [
              Text(
                'If you’re not sure',
                style: TextStyle(fontSize: 13.5, color: Ob.muted),
              ),
              SizedBox(height: 5),
              Text(
                'Skip it — you can pick later in Settings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Ob.parchment,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 · Sources
// ─────────────────────────────────────────────────────────────────────────────

/// Mirrors the retrieval corpus. Keep in sync with `dreamlore/src/sources.mjs`
/// and the library named in `dreamlore/src/prompt.mjs`.
const _library = <({String title, String author, String year})>[
  (
    title: 'The Interpretation of Dreams',
    author: 'Sigmund Freud',
    year: '1899',
  ),
  (title: 'Dream Psychology', author: 'Sigmund Freud', year: '1920'),
  (
    title: 'Ten Thousand Dreams Interpreted',
    author: 'Gustavus Hindman Miller',
    year: '1901',
  ),
];

class SourcesStep extends StatelessWidget {
  final bool active;
  const SourcesStep({super.key, this.active = true});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return StepScroll(
      active: active,
      children: [
        const BigTitle('Real books,\nreal quotes'),
        const SizedBox(height: 12),
        const Sub(
          'Most dream apps make up an answer. Dreamlore reads three '
          'classic dream books and shows you the exact lines.',
        ),
        const SizedBox(height: 26),
        for (final b in _library)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Semantics(
              label: '${b.title}, by ${b.author}, ${b.year}',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '“',
                      style: Ob.serif(size: 30, height: 1.9, color: primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.title,
                          style: Ob.serif(
                            size: 16.5,
                            style: FontStyle.italic,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${b.author} · ${b.year}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Ob.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        const InfoCard(
          icon: Icons.balance_outlined,
          title: 'And when the books have nothing to say',
          body:
              'Dreamlore tells you so plainly, instead of forcing '
              'an irrelevant quote.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 · Privacy
// ─────────────────────────────────────────────────────────────────────────────

class PrivacyStep extends StatelessWidget {
  final bool active;
  const PrivacyStep({super.key, this.active = true});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return StepScroll(
      active: active,
      children: [
        const BigTitle('Private\nby default'),
        const SizedBox(height: 12),
        const Sub('No account. No sign-in. No profile to build.'),
        const SizedBox(height: 26),
        const InfoCard(
          icon: Icons.graphic_eq,
          title: 'Your voice never leaves this phone',
          body:
              'Speech becomes text on this device as you talk. No audio file '
              'is created, saved, or uploaded.',
        ),
        const InfoCard(
          icon: Icons.lock_outline,
          title: 'Your journal stays here',
          body:
              'Entries live in this app, on this device. There is no cloud '
              'copy and no way for us to read them.',
        ),
        // Being straight about what does leave is both the honest answer and
        // the one Apple's privacy label requires — see docs/STORE-LISTING.md.
        InfoCard(
          icon: Icons.north_east,
          tint: Ob.muted,
          title: 'What does leave, once',
          body:
              'The text of a dream is sent at the moment you ask for a '
              'reading, so it can be interpreted. It is not stored afterwards.',
        ),
        InfoCard(
          icon: Icons.delete_outline,
          tint: t.colorScheme.error,
          title: 'Erase everything, anytime',
          body:
              'Settings → Clear all dreams removes every entry from this '
              'device, permanently.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 · Microphone
// ─────────────────────────────────────────────────────────────────────────────

class MicStep extends StatelessWidget {
  final MicStatus status;
  final VoidCallback onOpenSettings;
  final bool active;

  const MicStep({
    super.key,
    required this.status,
    required this.onOpenSettings,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return StepScroll(
      active: active,
      children: switch (status) {
        MicStatus.denied => [
          Center(
            child: Orb(
              size: 108,
              color: Ob.muted,
              icon: Icons.keyboard_alt_outlined,
            ),
          ),
          const SizedBox(height: 30),
          const BigTitle('No problem —\nyou can type'),
          const SizedBox(height: 12),
          const Sub(
            'Dreamlore works exactly the same way typed. Every reading, symbol '
            'and quote is identical.',
          ),
          const SizedBox(height: 26),
          const InfoCard(
            icon: Icons.keyboard_alt_outlined,
            title: 'Type on the Record tab',
            body:
                'The text field is always there, with or without the '
                'microphone.',
          ),
          InfoCard(
            icon: Icons.settings_outlined,
            tint: Ob.muted,
            title: 'Change your mind later',
            body: 'Turn the microphone on any time in your device settings.',
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open device settings'),
            ),
          ),
        ],
        MicStatus.granted => [
          Center(
            child: Orb(
              size: 108,
              color: primary,
              icon: Icons.check_rounded,
              lit: true,
            ),
          ),
          const SizedBox(height: 30),
          const BigTitle('You’re all set'),
          const SizedBox(height: 12),
          const Sub(
            'Tomorrow morning, open Dreamlore, tap the microphone, and say '
            'whatever you remember — even if it barely makes sense.',
          ),
          const SizedBox(height: 26),
          const InfoCard(
            icon: Icons.lock_outline,
            title: 'Nothing is recorded',
            body:
                'Speech becomes text as you talk, and the audio is '
                'discarded.',
          ),
        ],
        _ => [
          Center(
            child: Orb(size: 108, color: primary, icon: Icons.mic_none_rounded),
          ),
          const SizedBox(height: 30),
          const BigTitle('One thing\nbefore we start'),
          const SizedBox(height: 12),
          const Sub(
            'At 6am, typing is the last thing you want to do. Speaking works '
            'far better — but only if you let Dreamlore listen.',
          ),
          const SizedBox(height: 26),
          const InfoCard(
            icon: Icons.schedule,
            title: 'Only while you hold a recording',
            body:
                'Never in the background, never while you sleep. '
                'You start and stop it.',
          ),
          const InfoCard(
            icon: Icons.lock_outline,
            title: 'Nothing is recorded',
            body:
                'Your speech becomes text on this device as you talk. No '
                'audio file is created, saved, or uploaded.',
          ),
        ],
      },
    );
  }
}
