import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/ui_translation_controller.dart';
import '../../../../core/theme/zova_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/tr_text.dart';
import '../../../../data/models/exercise.dart';

/// Matching game: pair each word with its translation.
class PairsView extends StatefulWidget {
  const PairsView({
    super.key,
    required this.exercise,
    required this.onDone,
  });

  final Exercise exercise;
  final ValueChanged<bool> onDone;

  @override
  State<PairsView> createState() => _PairsViewState();
}

class _PairsViewState extends State<PairsView> {
  late final List<String> _words = widget.exercise.pairs.keys.toList()
    ..shuffle(Random(42));
  late final List<String> _translations =
      widget.exercise.pairs.values.toList()..shuffle();

  final Set<String> _matched = {};
  String? _selectedWord;
  String? _wrongTranslation;
  bool _finished = false;

  void _onTapWord(String word) {
    if (_matched.contains(word) || _finished) return;
    setState(() => _selectedWord = word);
  }

  void _onTapTranslation(String translation) {
    if (_finished) return;
    if (_selectedWord == null) {
      _flashWrong(translation);
      return;
    }
    final correct = widget.exercise.pairs[_selectedWord] == translation;
    if (correct) {
      setState(() {
        _matched.add(_selectedWord!);
        _selectedWord = null;
      });
      if (_matched.length == widget.exercise.pairs.length) {
        _finished = true;
      }
    } else {
      _flashWrong(translation);
    }
  }

  void _flashWrong(String translation) {
    setState(() => _wrongTranslation = translation);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _wrongTranslation = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final allMatched = _finished;
    context.watch<UiTranslationController?>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            widget.exercise.prompt,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.trTempl('{0}/{1} matched', [
              _matched.length,
              widget.exercise.pairs.length,
            ]),
            style: const TextStyle(color: ZovaColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final word in _words)
                  _PairTile(
                    label: word,
                    isWord: true,
                    matched: _matched.contains(word),
                    selected: _selectedWord == word,
                    onTap: () => _onTapWord(word),
                  ),
                for (final translation in _translations)
                  _PairTile(
                    label: translation,
                    isWord: false,
                    matched: _matched
                        .any((w) => widget.exercise.pairs[w] == translation),
                    wrong: _wrongTranslation == translation,
                    onTap: () => _onTapTranslation(translation),
                  ),
              ],
            ),
          ),
          if (allMatched) ...[
            const SizedBox(height: 12),
            GradientButton(
              label: context.tr('Continue'),
              icon: Icons.arrow_forward,
              onPressed: () => widget.onDone(true),
            ),
          ],
        ],
      ),
    );
  }
}

class _PairTile extends StatelessWidget {
  const _PairTile({
    required this.label,
    required this.isWord,
    required this.matched,
    required this.onTap,
    this.selected = false,
    this.wrong = false,
  });

  final String label;
  final bool isWord;
  final bool matched;
  final bool selected;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = matched
        ? ZovaColors.success.withValues(alpha: 0.12)
        : wrong
            ? ZovaColors.error.withValues(alpha: 0.12)
            : selected
                ? ZovaColors.primary.withValues(alpha: 0.18)
                : ZovaColors.surface;
    final Color border = matched
        ? ZovaColors.success
        : wrong
            ? ZovaColors.error
            : selected
                ? ZovaColors.primary
                : ZovaColors.surfaceRaised;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: matched ? 1.5 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: matched ? null : onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: matched ? ZovaColors.success : ZovaColors.textPrimary,
                  decoration: matched ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
