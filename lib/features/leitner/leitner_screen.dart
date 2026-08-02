import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/dictionary_entry.dart';
import '../../data/services/dictionary.dart';
import '../../data/services/dictionary_service.dart';
import 'leitner_review_screen.dart';

/// Schedule label shown for each Leitner box.
const List<String> kLeitnerSchedule = [
  'Every day',
  'Every 2 days',
  'Every 4 days',
  'Every 7 days',
  'Every 15 days',
];

/// Leitner Box: spaced repetition for your vocabulary.
///
/// Words start in box 1. Correct recalls promote them to the next box (less
/// frequent reviews), forgotten words drop back to box 1.
class LeitnerBoxScreen extends StatelessWidget {
  const LeitnerBoxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final boxes = controller.progress.leitnerBoxes;
    final total = boxes.length;
    final now = DateTime.now();
    final dueByBox = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    var dueToday = 0;
    for (final state in controller.progress.learning.values) {
      if (state.isDueAt(now)) {
        dueToday++;
        dueByBox[state.box] = (dueByBox[state.box] ?? 0) + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Leitner Box')),
      body: SafeArea(
        child: FutureBuilder<List<DictionaryService>>(
          future: Future.wait([Dictionary.service, GermanDictionary.service]),
          builder: (context, snapshot) {
            final dictionaries = snapshot.data;
            final english = dictionaries?[0];
            DictionaryEntry? resolve(String word) {
              if (dictionaries == null) return null;
              for (final dict in dictionaries) {
                final entry = dict.lookup(word);
                if (entry != null) return entry;
              }
              return null;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                const Text(
                  'Words you never forget',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Review words in short sessions. Right answers move words '
                  'to a higher box, wrong answers send them back to box 1.',
                  style: TextStyle(color: ZovaColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 18),
                _BoxStatsCard(total: total, dueToday: dueToday),
                if (english != null) ...[
                  const SizedBox(height: 16),
                  _WordPoolCard(dict: english, controller: controller),
                ],
                const SizedBox(height: 24),
                if (total == 0)
                  const _EmptyState()
                else ...[
                  const Text(
                    'Your boxes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var box = 1; box <= 5; box++) ...[
                    _BoxCard(
                      box: box,
                      schedule: kLeitnerSchedule[box - 1],
                      count: boxes.values.where((b) => b == box).length,
                      dueToday: dueByBox[box] ?? 0,
                      words: boxes.entries
                          .where((e) => e.value == box)
                          .map((e) => resolve(e.key))
                          .whereType<DictionaryEntry>()
                          .toList(),
                      onStudy: (words) {
                        if (words.isEmpty) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LeitnerReviewScreen(
                              box: box,
                              words: words,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A "pull from the dictionary" pool: picks a handful of words from a chosen
/// CEFR level via the indexed [DictionaryService] and lets the learner drop
/// them all into their Leitner boxes in one tap.
class _WordPoolCard extends StatefulWidget {
  const _WordPoolCard({required this.dict, required this.controller});

  final DictionaryService dict;
  final AppController controller;

  @override
  State<_WordPoolCard> createState() => _WordPoolCardState();
}

class _WordPoolCardState extends State<_WordPoolCard> {
  static const int _poolSize = 30;
  static const int _shown = 6;

  String _level = 'A1';
  int _seed = 0;
  List<DictionaryEntry> _pool = const [];

  @override
  void initState() {
    super.initState();
    _pool = _computePool();
  }

  List<DictionaryEntry> _computePool() {
    final result = widget.dict.searchPaged(
      DictionaryQuery(levels: [_level], limit: _poolSize),
    );
    final inBox = widget.controller.progress.leitnerBoxes;
    return result.items
        .where((e) => !inBox.containsKey(e.word))
        .toList()
      ..shuffle(Random(_seed));
  }

  void _refresh({bool reseed = false}) {
    if (reseed) _seed++;
    setState(() => _pool = _computePool());
  }

  void _addAll() {
    for (final entry in _pool) {
      widget.controller.addToLeitner(entry.word);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${_pool.length} words to your Leitner Box'),
      ),
    );
    _refresh(reseed: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ZovaColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style, color: ZovaColors.primary, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Word pool',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ZovaColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Shuffle',
                onPressed: () => _refresh(reseed: true),
                icon: const Icon(Icons.shuffle, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Practice a new level or shuffle — add a handful of words to your '
            'boxes straight from the dictionary.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: ZovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final level in kCefrLevels) ...[
                  ChoiceChip(
                    label: Text(
                      level,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: _level == level,
                    onSelected: (_) {
                      setState(() => _level = level);
                      _refresh();
                    },
                    visualDensity: VisualDensity.compact,
                    selectedColor: ZovaColors.primary,
                    backgroundColor: ZovaColors.surfaceRaised,
                    labelStyle: TextStyle(
                      color: _level == level
                          ? Colors.white
                          : ZovaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_pool.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No new words at this level — try another one.',
                style: TextStyle(color: ZovaColors.textSecondary),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _pool.take(_shown))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: ZovaColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.word,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ZovaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.translation,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ZovaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ZovaColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                ),
                onPressed: _addAll,
                icon: const Icon(Icons.playlist_add, size: 20),
                label: Text(
                  'Add ${_pool.take(_shown).length} words to my boxes',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoxStatsCard extends StatelessWidget {
  const _BoxStatsCard({required this.total, required this.dueToday});

  final int total;
  final int dueToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ZovaColors.gradientStart, ZovaColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.style, color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              total == 0
                  ? 'No words yet — add some to start reviewing.'
                  : dueToday == 0
                      ? '$total words across your boxes'
                      : '$total words · $dueToday due today',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome,
              color: ZovaColors.textSecondary, size: 34),
          SizedBox(height: 12),
          Text(
            'Build your Leitner Box',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ZovaColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Tap the bookmark on any dictionary word, or use "My Words" to '
            'add saved words to the box.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZovaColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxCard extends StatelessWidget {
  const _BoxCard({
    required this.box,
    required this.schedule,
    required this.count,
    required this.dueToday,
    required this.words,
    required this.onStudy,
  });

  final int box;
  final String schedule;
  final int count;
  final int dueToday;
  final List<DictionaryEntry> words;
  final void Function(List<DictionaryEntry> words) onStudy;

  @override
  Widget build(BuildContext context) {
    final color = switch (box) {
      1 => ZovaColors.error,
      2 => ZovaColors.warning,
      3 => ZovaColors.primary,
      4 => ZovaColors.secondary,
      _ => ZovaColors.success,
    };

    final dueLabel = dueToday == 0
        ? null
        : ' · $dueToday due today';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$box',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Box $box',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$schedule · $count ${count == 1 ? 'word' : 'words'}$dueLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ZovaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: count == 0 ? null : () => onStudy(words),
            style: TextButton.styleFrom(
              disabledForegroundColor:
                  ZovaColors.textSecondary.withValues(alpha: 0.4),
            ),
            child: const Text('Study'),
          ),
        ],
      ),
    );
  }
}
