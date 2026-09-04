import 'package:flutter/material.dart';
import '../data/models.dart';

/// Renders a dream interpretation (explanation, symbols, quotes, reflection).
/// Reused by the record result and the saved-entry detail screen.
class InterpretationView extends StatelessWidget {
  final String transcript;
  final Interpretation interp;
  final EdgeInsetsGeometry padding;

  const InterpretationView({
    super.key,
    required this.transcript,
    required this.interp,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: padding,
      children: [
        _label(context, 'YOUR DREAM'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(transcript, style: t.textTheme.bodyMedium),
          ),
        ),
        const SizedBox(height: 22),
        _label(context, 'INTERPRETATION'),
        Text(interp.explanation, style: t.textTheme.bodyLarge?.copyWith(height: 1.5)),
        if (interp.symbols.isNotEmpty) ...[
          const SizedBox(height: 22),
          _label(context, 'SYMBOLS'),
          ...interp.symbols.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RichText(
                text: TextSpan(
                  style: t.textTheme.bodyMedium?.copyWith(height: 1.4),
                  children: [
                    TextSpan(
                      text: '${s.symbol}  ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.colorScheme.primary,
                      ),
                    ),
                    TextSpan(text: s.meaning),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (interp.quotes.isNotEmpty) ...[
          const SizedBox(height: 22),
          _label(context, 'FROM THE DREAM LIBRARY'),
          ...interp.quotes.map(
            (q) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('“${q.text}”',
                        style: t.textTheme.bodyMedium
                            ?.copyWith(fontStyle: FontStyle.italic, height: 1.4)),
                    const SizedBox(height: 8),
                    Text('— ${q.author}, ${q.book}',
                        style: t.textTheme.labelMedium
                            ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (interp.reflection.isNotEmpty) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.self_improvement, color: t.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(interp.reflection,
                        style: t.textTheme.bodyMedium?.copyWith(height: 1.4))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'A reflective reading, not medical, psychological, or predictive advice.',
          style: t.textTheme.labelSmall
              ?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _label(BuildContext c, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          s,
          style: Theme.of(c).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.3,
                fontWeight: FontWeight.w600,
                color: Theme.of(c).colorScheme.primary,
              ),
        ),
      );
}
