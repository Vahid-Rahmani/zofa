import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/models/translation_result.dart';
import '../../data/services/english_grammar.dart';
import '../../data/services/translation_service.dart';

/// Full dictionary-style study card for one word from the 50k vocabulary list.
///
/// Loads the live translation into the learner's learning language (the
/// "second language", cached on device), shows the part of speech and — when
/// the word is a verb — an Active/Passive conjugation table for Present / Past
/// / Future, plus example sentences. Every verb form and example is also
/// translated live into the learning language, so the learner reads English
/// and its gloss side by side.
class WordStudyScreen extends StatefulWidget {
  const WordStudyScreen({super.key, required this.word, this.level, this.rank});

  final String word;

  /// CEFR level of the word (`A1` … `C2`), when known.
  final String? level;

  /// Frequency rank of the word (1-based), when known.
  final int? rank;

  @override
  State<WordStudyScreen> createState() => _WordStudyScreenState();
}

class _WordStudyScreenState extends State<WordStudyScreen> {
  TranslationResult? _result;
  TranslationException? _error;
  EnglishGrammar? _grammar;
  bool _loading = true;
  bool _loadingGlosses = false;

  /// English phrase → translated gloss in the learner's learning language.
  final Map<String, String> _glosses = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _word => widget.word;

  Future<void> _load() async {
    final target =
        context.read<LanguageController>().settings.contentLanguageCode;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await TranslationService.instance.lookup(
        word: _word,
        source: 'en',
        target: target,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on TranslationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
      return;
    }
    await _translateGrammar(target);
  }

  /// Loads the grammar data and live-translates the verb forms and example
  /// sentences that apply to this word (all concurrently; each is cached).
  Future<void> _translateGrammar(String target) async {
    final grammar = await EnglishGrammar.service;
    if (!mounted) return;
    final phrases = _phrasesToTranslate(grammar);
    if (phrases.isEmpty) return;
    setState(() {
      _grammar = grammar;
      _loadingGlosses = true;
    });
    await Future.wait(phrases.map((phrase) async {
      if (_glosses.containsKey(phrase)) return;
      try {
        final gloss = await TranslationService.instance.lookup(
          word: phrase,
          source: 'en',
          target: target,
        );
        if (gloss.translation.isNotEmpty) _glosses[phrase] = gloss.translation;
      } on TranslationException {
        // Leave the phrase untranslated; the English form is shown instead.
      }
    }));
    if (!mounted) return;
    setState(() => _loadingGlosses = false);
  }

  List<String> _phrasesToTranslate(EnglishGrammar grammar) {
    final section = grammar.sectionOf(_word);
    final phrases = <String>[...grammar.exampleSentences(_word, section)];
    final forms = grammar.verbForms(_word);
    if (forms != null) {
      phrases.addAll([...forms.active, ...forms.passive]);
    }
    return phrases.toSet().toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_word, style: const TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _result == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 14),
            TrText(
              'Translating…',
              style: TextStyle(color: ZovaColors.textSecondary),
            ),
          ],
        ),
      );
    }
    final error = _error;
    if (error != null && _result == null) {
      return _ErrorState(message: error.message, onRetry: _load);
    }
    final result = _result;
    if (result == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    final grammar = _grammar;
    final pos = grammar?.partOfSpeech(_word) ?? result.partOfSpeech;
    final forms = grammar?.verbForms(_word);
    final examples = grammar == null
        ? const <String>[]
        : grammar.exampleSentences(_word, grammar.sectionOf(_word));
    final rtl = result.isRtl;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _word,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                  if (pos != null) ...[
                    const SizedBox(height: 6),
                    _Chip(
                      icon: Icons.category_outlined,
                      label: context.tr(pos),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(
              label: result.fromCache ? 'Cached' : 'Live',
              live: !result.fromCache,
            ),
          ],
        ),
        if (widget.level != null || widget.rank != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (widget.level != null) _LevelChip(level: widget.level!),
              if (widget.rank != null) ...[
                const Icon(Icons.tag, size: 15, color: ZovaColors.textSecondary),
                Text(
                  '#${widget.rank}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ZovaColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ZovaColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            result.translation,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ZovaColors.secondary,
            ),
          ),
        ),
        if (result.definition != null && result.definition!.isNotEmpty) ...[
          const SizedBox(height: 18),
          const TrText(
            'Meaning',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.definition!,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: ZovaColors.textPrimary,
            ),
          ),
        ],
        if (result.alternates.isNotEmpty) ...[
          const SizedBox(height: 18),
          const TrText(
            'Other translations',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final alt in result.alternates)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ZovaColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    alt,
                    textDirection:
                        rtl ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (forms != null) ...[
          const SizedBox(height: 22),
          _VerbFormsCard(
            forms: forms,
            glosses: _glosses,
            loadingGlosses: _loadingGlosses,
            rtl: rtl,
          ),
        ],
        if (examples.isNotEmpty) ...[
          const SizedBox(height: 18),
          const TrText(
            'Examples',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final example in examples) ...[
            _ExampleTile(
              english: example,
              gloss: _glosses[example],
              loadingGlosses: _loadingGlosses,
              rtl: rtl,
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 18),
        _SaveLeitnerRow(word: _word),
        const SizedBox(height: 24),
        const TrText(
          'Practice it',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ZovaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        const TrText(
          'Save this word to "My Words" or drop it into a Leitner box to '
          'review it with flashcards until you never forget it.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: ZovaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Rows of the Active/Passive × Present/Past/Future conjugation table, each
/// cell showing the English form and its live-translated gloss.
class _VerbFormsCard extends StatelessWidget {
  const _VerbFormsCard({
    required this.forms,
    required this.glosses,
    required this.loadingGlosses,
    required this.rtl,
  });

  final VerbForms forms;
  final Map<String, String> glosses;
  final bool loadingGlosses;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    final tenses = ['Present', 'Past', 'Future'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrText(
              'Verb forms',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 64),
                Expanded(
                  child: _CellHeader(label: context.tr('Active')),
                ),
                Expanded(
                  child: _CellHeader(label: context.tr('Passive')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < 3; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      context.tr(tenses[i]),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ZovaColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _FormCell(
                      english: forms.active[i],
                      gloss: glosses[forms.active[i]],
                      loadingGlosses: loadingGlosses,
                      rtl: rtl,
                    ),
                  ),
                  Expanded(
                    child: _FormCell(
                      english: forms.passive[i],
                      gloss: glosses[forms.passive[i]],
                      loadingGlosses: loadingGlosses,
                      rtl: rtl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CellHeader extends StatelessWidget {
  const _CellHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: ZovaColors.primary,
      ),
    );
  }
}

class _FormCell extends StatelessWidget {
  const _FormCell({
    required this.english,
    required this.gloss,
    required this.loadingGlosses,
    required this.rtl,
  });

  final String english;
  final String? gloss;
  final bool loadingGlosses;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ZovaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            english,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          if (gloss != null)
            Text(
              gloss!,
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(
                fontSize: 13,
                color: ZovaColors.textSecondary,
              ),
            )
          else if (loadingGlosses)
            const Text(
              '…',
              style: TextStyle(
                fontSize: 13,
                color: ZovaColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile({
    required this.english,
    required this.gloss,
    required this.loadingGlosses,
    required this.rtl,
  });

  final String english;
  final String? gloss;
  final bool loadingGlosses;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '“$english”',
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: ZovaColors.textPrimary,
          ),
        ),
        if (gloss != null) ...[
          const SizedBox(height: 2),
          Text(
            gloss!,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: ZovaColors.textSecondary,
            ),
          ),
        ] else if (loadingGlosses) ...[
          const SizedBox(height: 2),
          const Text(
            '…',
            style: TextStyle(
              fontSize: 15,
              color: ZovaColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _SaveLeitnerRow extends StatelessWidget {
  const _SaveLeitnerRow({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    context.watch<UiTranslationController?>();
    final scope =
        context.read<LanguageController>().settings.learningLanguage;
    final isSaved = controller.progress.savedWordsFor(scope).contains(word);
    final inLeitner =
        controller.progress.leitnerBoxesFor(scope).containsKey(word);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              foregroundColor:
                  isSaved ? ZovaColors.success : ZovaColors.textPrimary,
            ),
            onPressed: () {
              if (isSaved) {
                controller.removeSavedWord(word);
              } else {
                controller.saveWord(word);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isSaved
                        ? context.tr('Removed from My Words')
                        : context.tr('Saved to My Words'),
                  ),
                ),
              );
            },
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_outline,
              size: 20,
            ),
            label: Text(context.tr(isSaved ? 'Saved' : 'Save')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              foregroundColor: ZovaColors.primary,
            ),
            onPressed: inLeitner
                ? null
                : () {
                    controller.addToLeitner(word);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Added to Leitner Box')),
                      ),
                    );
                  },
            icon: const Icon(Icons.style_outlined, size: 20),
            label: Text(context.tr(inLeitner ? 'In Leitner' : 'Leitner')),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ZovaColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ZovaColors.primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ZovaColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _levelColor(String level) => switch (level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      'B1' => ZovaColors.warning,
      'B2' => ZovaColors.secondary,
      'C1' => ZovaColors.info,
      'C2' => ZovaColors.gold,
      _ => ZovaColors.primary,
    };

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.live});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? ZovaColors.success : ZovaColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.tr(label),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: ZovaColors.error, size: 44),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ZovaColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: ZovaColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.tr('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}
