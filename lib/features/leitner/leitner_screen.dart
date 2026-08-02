import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/translation_language.dart';
import '../../data/models/translation_result.dart';
import '../../data/offline/starter_words.dart';
import '../../data/services/translation_service.dart';
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
/// frequent reviews), forgotten words drop back to box 1. Translations are
/// resolved live through the [TranslationService] (cached, so they survive
/// offline).
class LeitnerBoxScreen extends StatefulWidget {
  const LeitnerBoxScreen({super.key});

  @override
  State<LeitnerBoxScreen> createState() => _LeitnerBoxScreenState();
}

class _LeitnerBoxScreenState extends State<LeitnerBoxScreen> {
  final Map<String, TranslationResult> _resolved = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final controller = context.read<AppController>();
    final languageCode =
        context.read<LanguageController>().settings.translationLanguage.code;
    _resolved.clear();
    for (final word in controller.progress.leitnerBoxes.keys) {
      await _resolve(word, languageCode);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resolve(String word, String languageCode) async {
    try {
      final result = await TranslationService.instance.lookupAnySource(
        word: word,
        target: languageCode,
      );
      _resolved[word] = result ??
          TranslationResult(
            word: word,
            source: 'en',
            target: languageCode,
            translation: '',
          );
    } on TranslationException {
      _resolved[word] = TranslationResult(
        word: word,
        source: 'en',
        target: languageCode,
        translation: '',
      );
    }
  }

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
        child: ListView(
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
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 18),
            _BoxStatsCard(total: total, dueToday: dueToday),
            const SizedBox(height: 16),
            _WordPoolCard(controller: controller),
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
                      .map((e) => _resolved[e.key])
                      .whereType<TranslationResult>()
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
        ),
      ),
    );
  }
}

/// A suggested word and its (optional, lazily loaded) translation.
typedef _PoolWord = ({String word, String? translation});

/// A "pull from the starter lists" pool: suggests common words for the chosen
/// source language and CEFR level, resolves their translations live and lets
/// the learner drop them all into their Leitner boxes in one tap.
class _WordPoolCard extends StatefulWidget {
  const _WordPoolCard({required this.controller});

  final AppController controller;

  @override
  State<_WordPoolCard> createState() => _WordPoolCardState();
}

class _WordPoolCardState extends State<_WordPoolCard> {
  static const int _shown = 6;

  String _source = 'en';
  String _level = 'A1';
  int _seed = 0;
  List<_PoolWord> _pool = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _computePool();
  }

  Future<void> _computePool({bool reseed = false}) async {
    if (reseed) _seed++;
    setState(() => _loading = true);
    final inBox = widget.controller.progress.leitnerBoxes;
    final candidates = starterWordsFor(_source, _level)
        .where((word) => !inBox.containsKey(word))
        .toList()
      ..shuffle(Random(_seed));

    final languageCode =
        context.read<LanguageController>().settings.translationLanguage.code;
    final resolved = <_PoolWord>[];
    for (final word in candidates.take(_shown)) {
      String? translation;
      try {
        final result = await TranslationService.instance.lookup(
          word: word,
          source: _source,
          target: languageCode,
        );
        translation = result.translation;
      } on TranslationException {
        translation = null;
      }
      resolved.add((word: word, translation: translation));
    }
    if (mounted) {
      setState(() {
        _pool = resolved;
        _loading = false;
      });
    }
  }

  void _addAll() {
    for (final poolWord in _pool) {
      widget.controller.addToLeitner(poolWord.word);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${_pool.length} words to your Leitner Box'),
      ),
    );
    _computePool(reseed: true);
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
                onPressed: () => _computePool(reseed: true),
                icon: const Icon(Icons.shuffle, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Common starter words for your language — add a handful to your '
            'boxes straight away. Translations load live and stay cached.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: ZovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final language in kStarterWords.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      language.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: _source == language,
                    onSelected: (_) {
                      setState(() => _source = language);
                      _computePool();
                    },
                    visualDensity: VisualDensity.compact,
                    selectedColor: ZovaColors.primary,
                    backgroundColor: ZovaColors.surfaceRaised,
                    labelStyle: TextStyle(
                      color: _source == language
                          ? Colors.white
                          : ZovaColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final level in kStarterLevels) ...[
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
                      _computePool();
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
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (_pool.isEmpty)
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
                for (final poolWord in _pool)
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
                          poolWord.word,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ZovaColors.textPrimary,
                          ),
                        ),
                        if (poolWord.translation != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            poolWord.translation!,
                            textDirection: _isRtlTarget()
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ZovaColors.textSecondary,
                            ),
                          ),
                        ],
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
                  'Add ${_pool.length} words to my boxes',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isRtlTarget() =>
      TranslationLanguage.byCode(
            context.read<LanguageController>().settings.translationLanguage.code,
          )?.isRtl ??
      false;
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
  final List<TranslationResult> words;
  final void Function(List<TranslationResult> words) onStudy;

  @override
  Widget build(BuildContext context) {
    final color = switch (box) {
      1 => ZovaColors.error,
      2 => ZovaColors.warning,
      3 => ZovaColors.primary,
      4 => ZovaColors.secondary,
      _ => ZovaColors.success,
    };

    final dueLabel = dueToday == 0 ? null : ' · $dueToday due today';

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
