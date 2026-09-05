import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/repositories/dream_repository.dart';
import '../../providers/providers.dart';
import '../../ui/cards.dart';
import '../../ui/motion.dart';
import '../../ui/night.dart';
import '../../ui/scaffold.dart';
import '../entry/entry_detail_screen.dart';

/// The journal, built for a year of dreams rather than a week of them.
///
/// A flat list is fine at ten entries and useless at three hundred, so there
/// are three ways in, and they compose:
///
/// * **Search** — matches the dream's words and its symbols.
/// * **Symbol chips** — the images that actually recur in *your* journal,
///   most frequent first. One tap narrows to every night that shared it.
/// * **Two shapes** — the timeline for reading, a picture grid for finding.
///   With a painting on most entries the grid is the fastest way to spot the
///   night you are thinking of, because you remember dreams as images.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _symbol;
  bool _grid = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(DreamEntry e) {
    if (_symbol != null &&
        !e.symbolList.any(
          (s) => s.symbol.toLowerCase() == _symbol!.toLowerCase(),
        )) {
      return false;
    }
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    if (e.transcript.toLowerCase().contains(q)) return true;
    return e.symbolList.any((s) => s.symbol.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final dreams = ref.watch(dreamsStreamProvider);

    return NightScaffold(
      title: 'Journal',
      padded: false,
      child: dreams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.menu_book_outlined,
          title: "Couldn't open your journal",
          body:
              'Your entries are safe on this device. Reopening the app '
              'usually clears this.',
          action: SizedBox(
            width: 220,
            child: PrimaryPill(
              label: 'Try again',
              onPressed: () => ref.invalidate(dreamsStreamProvider),
            ),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.nightlight_round,
              title: 'No dreams yet',
              body:
                  'Log one when you wake and it will appear here — along '
                  'with the symbols it shares with the nights after it.',
            );
          }

          // The symbols worth offering as filters: the ones that actually
          // repeat. A symbol seen once is noise in a filter row.
          final counts = <String, int>{};
          for (final e in all) {
            for (final s in e.symbolList) {
              final k = s.symbol.trim();
              if (k.isEmpty) continue;
              counts.update(k, (v) => v + 1, ifAbsent: () => 1);
            }
          }
          final chips =
              (counts.entries.where((e) => e.value > 1).toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(10)
                  .toList();

          final list = all.where(_matches).toList();
          final filtering = _query.isNotEmpty || _symbol != null;

          return Column(
            children: [
              _Toolbar(
                controller: _search,
                grid: _grid,
                // The controls only earn their space once the journal is big
                // enough to be hard to scan.
                showTools: all.length >= 6,
                onQuery: (v) => setState(() => _query = v),
                onToggleShape: () => setState(() => _grid = !_grid),
              ),
              if (chips.isNotEmpty && all.length >= 6)
                _SymbolFilters(
                  chips: chips,
                  selected: _symbol,
                  onSelect: (s) => setState(() => _symbol = s),
                ),
              if (filtering)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: Row(
                    children: [
                      Text(
                        list.isEmpty
                            ? 'No dreams match'
                            : '${list.length} of ${all.length} dreams',
                        style: const TextStyle(fontSize: 12.5, color: Ob.muted),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {
                            _query = '';
                            _symbol = null;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nothing here',
                        body: _symbol != null
                            ? 'No dream mentions “$_symbol” with those words.'
                            : 'No dream has those words in it yet.',
                      )
                    : StateSwitcher(
                        child: _grid
                            ? _Gallery(
                                key: const ValueKey('grid'),
                                entries: list,
                              )
                            : _Timeline(
                                key: const ValueKey('list'),
                                entries: list,
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Search field plus the timeline/gallery switch.
class _Toolbar extends StatelessWidget {
  final TextEditingController controller;
  final bool grid;
  final bool showTools;
  final ValueChanged<String> onQuery;
  final VoidCallback onToggleShape;

  const _Toolbar({
    required this.controller,
    required this.grid,
    required this.showTools,
    required this.onQuery,
    required this.onToggleShape,
  });

  @override
  Widget build(BuildContext context) {
    if (!showTools) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: Ob.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onQuery,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Ob.parchment,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Search your dreams',
                        hintStyle: TextStyle(fontSize: 14.5, color: Ob.muted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        controller.clear();
                        onQuery('');
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Ob.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          PressScale(
            child: Semantics(
              button: true,
              label: grid ? 'Show as a list' : 'Show as pictures',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggleShape();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Icon(
                    grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                    size: 20,
                    color: Ob.parchment,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The symbols that recur in this journal, as a scrolling row of filters.
class _SymbolFilters extends StatelessWidget {
  final List<MapEntry<String, int>> chips;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _SymbolFilters({
    required this.chips,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = chips[i];
          final on = selected == c.key;
          return PressScale(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(on ? null : c.key);
              },
              child: AnimatedContainer(
                duration: Motion.quick,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on
                      ? primary.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: on
                        ? primary.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Text(
                  '${c.key}  ${c.value}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: on ? Ob.parchment : Ob.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The reading shape: entries grouped under the night they belong to.
class _Timeline extends StatelessWidget {
  final List<DreamEntry> entries;
  const _Timeline({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[];
    String? current;
    for (final e in entries) {
      final label = _groupLabel(e.createdAt);
      if (label != current) {
        current = label;
        rows.add(label);
      }
      rows.add(e);
    }

    return ListView.builder(
      // Explicit padding drops the extendBody inset — add the nav-bar
      // clearance back or the newest entry hides under the capsule.
      padding: EdgeInsets.fromLTRB(
        22,
        10,
        22,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.fromLTRB(2, i == 0 ? 0 : 18, 2, 12),
            child: Text(
              row.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
                color: Ob.muted,
              ),
            ),
          );
        }
        return Reveal(
          // Only the first screenful staggers; rows further down arrive as
          // the user scrolls to them and need no delay.
          index: i < 8 ? i : 0,
          child: _EntryCard(entry: row as DreamEntry),
        );
      },
    );
  }
}

/// The finding shape: every painting, three across, newest first. Entries
/// with no picture keep their place as a quiet card so nothing is hidden.
class _Gallery extends StatelessWidget {
  final List<DreamEntry> entries;
  const _Gallery({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return Reveal(
          index: i < 9 ? i : 0,
          offset: 10,
          child: _GalleryTile(entry: e),
        );
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final DreamEntry entry;
  const _GalleryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final has = entry.imagePath.isNotEmpty;
    final day = DateFormat.Md().format(entry.createdAt);
    return PressScale(
      child: Semantics(
        button: true,
        label:
            '${DateFormat.yMMMEd().format(entry.createdAt)}. '
            '${entry.transcript}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => EntryDetailScreen(entry))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (has)
                  Image.file(
                    File(entry.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _NoPicture(),
                  )
                else
                  _NoPicture(text: entry.transcript),
                // A date, legible over any painting.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Ob.inkDeep.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Ob.parchment,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dream with no painting: its first words on the night ground, so the grid
/// stays complete rather than silently dropping entries.
class _NoPicture extends StatelessWidget {
  final String? text;
  const _NoPicture({this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(10),
      alignment: Alignment.topLeft,
      child: Text(
        text ?? '',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Ob.serif(size: 11.5, height: 1.3, color: Ob.muted),
      ),
    );
  }
}

/// Recent nights get relative names; older ones fall back to the month, which
/// is how people actually remember when they dreamt something.
String _groupLabel(DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final delta = today.difference(day).inDays;
  if (delta <= 0) return 'Today';
  if (delta == 1) return 'Yesterday';
  if (delta < 7) return 'Earlier this week';
  if (delta < 30) return 'Earlier this month';
  return DateFormat.yMMMM().format(when);
}

class _EntryCard extends StatelessWidget {
  final DreamEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final symbols = entry.symbolList.take(3).map((s) => s.symbol).toList();
    final date = DateFormat.yMMMEd().add_jm().format(entry.createdAt);
    final short = DateFormat.jm().format(entry.createdAt);
    final hasImage = entry.imagePath.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: '$date. ${entry.transcript}',
        excludeSemantics: true,
        child: PressScale(
          pressedScale: 0.985,
          child: Material(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EntryDetailScreen(entry)),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A date column, the way every long-history journal does
                    // it: the eye runs down one edge to find a night rather
                    // than reading every row.
                    SizedBox(
                      width: 42,
                      child: Column(
                        children: [
                          Text(
                            DateFormat.d().format(entry.createdAt),
                            style: const TextStyle(
                              fontSize: 19,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: Ob.parchment,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.MMM()
                                .format(entry.createdAt)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                              color: Ob.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            short.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                              color: Ob.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.transcript,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              height: 1.45,
                              color: Ob.parchment,
                            ),
                          ),
                          if (symbols.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final s in symbols)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasImage) ...[
                      const SizedBox(width: 14),
                      Hero(
                        tag: 'dream-image-${entry.imagePath}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(entry.imagePath),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            // A picture whose file went missing should not
                            // take the whole row down with it.
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 72, height: 72),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
