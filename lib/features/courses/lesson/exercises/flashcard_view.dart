import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/language_controller.dart';
import '../../../../core/state/ui_translation_controller.dart';
import '../../../../core/theme/zova_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/tr_text.dart';
import '../../../../data/models/exercise.dart';
import '../../../../data/models/translation_result.dart';
import '../../../../data/services/translation_service.dart';

/// Study session: flip a card to reveal the live translation and example, then
/// mark the word as known or still learning.
class FlashcardView extends StatefulWidget {
  const FlashcardView({
    super.key,
    required this.exercise,
    required this.onDone,
  });

  final Exercise exercise;
  final ValueChanged<bool> onDone;

  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> {
  late final List<String> _words = widget.exercise.words;
  int _index = 0;
  bool _flipped = false;
  int _known = 0;

  void _answer(bool known) {
    if (known) _known++;
    if (_index < _words.length - 1) {
      setState(() {
        _index++;
        _flipped = false;
      });
    } else {
      widget.onDone(_known > 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Container(
                    key: ValueKey(_flipped),
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 320),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: _flipped
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                ZovaColors.gradientStart,
                                ZovaColors.gradientEnd,
                              ],
                            ),
                      color: _flipped ? ZovaColors.surface : null,
                      borderRadius: BorderRadius.circular(28),
                      border: _flipped
                          ? Border.all(color: ZovaColors.primary)
                          : null,
                    ),
                    child: Center(
                      child: _flipped
                          ? _FlippedCard(
                              word: _words[_index],
                              example: _exampleOf(_words[_index]),
                            )
                          : Text(
                              _words[_index],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TrText(
            'Tap the card to flip it',
            style: TextStyle(
              fontSize: 13,
              color: ZovaColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _answer(false),
                  child: Text(context.tr('Still learning')),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GradientButton(
                  label: context.tr('Got it'),
                  onPressed: () => _answer(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_index + 1} / ${_words.length}',
            style: const TextStyle(color: ZovaColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _exampleOf(String word) {
    final examples = widget.exercise.examples;
    final example = examples[word];
    if (example != null && example.isNotEmpty) return example;
    return widget.exercise.pairs[word] ?? '';
  }
}

/// The revealed (back) face of a card: the word, its live translation into the
/// learner's native language, and a contextual example sentence.
class _FlippedCard extends StatelessWidget {
  const _FlippedCard({required this.word, required this.example});

  final String word;
  final String example;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          word,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ZovaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _WordTranslation(word: word),
        if (example.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            example,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: ZovaColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}

/// Live-translates [word] into the learner's content language. Falls back to a
/// silent empty slot while loading or when the lookup is unavailable, so the
/// card stays useful offline.
class _WordTranslation extends StatefulWidget {
  const _WordTranslation({required this.word});

  final String word;

  @override
  State<_WordTranslation> createState() => _WordTranslationState();
}

class _WordTranslationState extends State<_WordTranslation> {
  TranslationResult? _result;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final target =
        context.read<LanguageController>().settings.contentLanguageCode;
    TranslationResult? result;
    try {
      result = await TranslationService.instance
          .lookupAnySource(word: widget.word, target: target);
    } on Exception {
      result = null;
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _settled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result == null) {
      // Keep the card height stable while the gloss is being fetched.
      return SizedBox(height: _settled ? 0 : 20);
    }
    return Text(
      result.translation,
      textAlign: TextAlign.center,
      textDirection: result.isRtl ? TextDirection.rtl : TextDirection.ltr,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ZovaColors.secondary,
      ),
    );
  }
}
