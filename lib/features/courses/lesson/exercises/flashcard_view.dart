import 'package:flutter/material.dart';

import '../../../../core/theme/zova_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../data/models/exercise.dart';

/// Study session: flip a card to reveal the translation, then mark it as
/// known or still learning.
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
                    constraints: const BoxConstraints(maxHeight: 300),
                    padding: const EdgeInsets.all(32),
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
                      child: Text(
                        _flipped ? _translationOf(_words[_index]) : _words[_index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _flipped
                              ? ZovaColors.textPrimary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
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
                  child: const Text('Still learning'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GradientButton(
                  label: 'Got it',
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

  String _translationOf(String word) {
    final pairs = widget.exercise.pairs;
    return pairs[word] ?? word;
  }
}
