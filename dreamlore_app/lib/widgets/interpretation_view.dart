import 'package:flutter/material.dart';

import '../data/models.dart';
import '../ui/motion.dart';
import '../ui/night.dart';

/// Renders a dream interpretation (explanation, symbols, quotes, reflection).
/// Reused by the record result and the saved-entry detail screen.
///
/// Sections settle in one after another on first build — the reading has just
/// been written, and it should arrive like one, not appear as a wall.
class InterpretationView extends StatelessWidget {
  final String transcript;
  final Interpretation interp;
  final EdgeInsetsGeometry padding;

  /// The dream's picture (or the invitation to make one), shown right under
  /// the dream itself — the image belongs to the dream, not to the reading.
  final Widget? picture;

  /// Set false on a saved entry: it was read long ago, so it is simply there.
  final bool animate;

  const InterpretationView({
    super.key,
    required this.transcript,
    required this.interp,
    this.padding = const EdgeInsets.all(16),
    this.picture,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    var i = 0;
    Widget reveal(Widget w) => animate ? Reveal(index: i++, child: w) : w;

    return ListView(
      padding: padding,
      children: [
        reveal(_label(context, 'YOUR DREAM')),
        reveal(
          _Panel(
            child: Text(
              transcript,
              style: Ob.serif(size: 17, height: 1.5, color: Ob.parchment),
            ),
          ),
        ),
        if (picture != null) ...[const SizedBox(height: 14), reveal(picture!)],
        const SizedBox(height: 26),
        reveal(_label(context, 'WHAT IT MIGHT MEAN')),
        reveal(
          Text(
            interp.explanation,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Ob.parchment,
            ),
          ),
        ),
        if (interp.symbols.isNotEmpty) ...[
          const SizedBox(height: 26),
          reveal(_label(context, 'THINGS IN YOUR DREAM')),
          reveal(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in interp.symbols) _SymbolChip(symbol: s),
              ],
            ),
          ),
        ],
        if (interp.quotes.isNotEmpty) ...[
          const SizedBox(height: 26),
          reveal(_label(context, 'FROM THE BOOKS')),
          ...interp.quotes.map(
            (q) => reveal(
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _Panel(
                  accent: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '“${q.text}”',
                        style: Ob.serif(
                          size: 16.5,
                          height: 1.45,
                          style: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${q.author}  ·  ${q.book}',
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.3,
                          color: Ob.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        if (interp.reflection.isNotEmpty) ...[
          const SizedBox(height: 18),
          reveal(
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: t.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: t.colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.self_improvement, color: t.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      interp.reflection,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Ob.parchment,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        reveal(
          const Text(
            'A reflective reading, not medical, psychological, or predictive advice.',
            style: TextStyle(fontSize: 11.5, height: 1.4, color: Ob.muted),
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext c, String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(s, style: Ob.eyebrow(c)),
  );
}

/// The translucent panel used by the record screen's text field, so the
/// dream and its quotes sit on the same surface everywhere.
class _Panel extends StatelessWidget {
  final Widget child;
  final bool accent;
  const _Panel({required this.child, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(22);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(accent ? 22 : 18, 16, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: child,
          ),
          // The quote's accent: a slim indigo bar down the left edge. Drawn
          // separately because a rounded border cannot vary per side.
          if (accent)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 3, color: primary.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }
}

/// A symbol and its meaning as one rounded chip that opens on tap, so a
/// reading with eight symbols is a scannable row rather than a column of
/// paragraphs.
class _SymbolChip extends StatefulWidget {
  final DreamSymbol symbol;
  const _SymbolChip({required this.symbol});
  @override
  State<_SymbolChip> createState() => _SymbolChipState();
}

class _SymbolChipState extends State<_SymbolChip> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _open = !_open),
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.curve,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: _open ? double.infinity : 260,
            ),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: _open ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: primary.withValues(alpha: _open ? 0.45 : 0.2),
              ),
            ),
            child: AnimatedSize(
              duration: Motion.base,
              curve: Motion.curve,
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.symbol.symbol,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: Motion.quick,
                        child: Icon(
                          Icons.expand_more,
                          size: 16,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  if (_open) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.symbol.meaning,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Ob.parchment,
                      ),
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
