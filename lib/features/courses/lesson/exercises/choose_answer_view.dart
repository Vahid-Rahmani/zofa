import 'package:flutter/material.dart';

import '../../../../core/theme/zova_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../data/models/exercise.dart';

/// Multiple-choice question: pick the correct translation for the prompt.
class ChooseAnswerView extends StatefulWidget {
  const ChooseAnswerView({
    super.key,
    required this.exercise,
    required this.onDone,
  });

  final Exercise exercise;
  final ValueChanged<bool> onDone;

  @override
  State<ChooseAnswerView> createState() => _ChooseAnswerViewState();
}

class _ChooseAnswerViewState extends State<ChooseAnswerView> {
  late final List<String> _options = _shuffled();
  String? _selected;
  bool _answered = false;

  void _choose(String option) {
    if (_answered) return;
    setState(() {
      _selected = option;
      _answered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                widget.exercise.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.textPrimary,
                ),
              ),
            ),
          ),
          for (final option in _options) ...[
            _OptionTile(
              option: option,
              state: _stateFor(option),
              onTap: () => _choose(option),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          if (_answered)
            GradientButton(
              label: 'Continue',
              icon: Icons.arrow_forward,
              onPressed: () => widget.onDone(_isCorrect),
            ),
        ],
      ),
    );
  }

  bool get _isCorrect =>
      _selected != null && _selected == widget.exercise.correctAnswer;

  _TileState _stateFor(String option) {
    if (!_answered) return _TileState.idle;
    if (option == widget.exercise.correctAnswer) return _TileState.correct;
    if (option == _selected) return _TileState.wrong;
    return _TileState.dimmed;
  }

  List<String> _shuffled() {
    final options = List<String>.from(widget.exercise.options);
    options.shuffle();
    return options;
  }
}

enum _TileState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.state,
    required this.onTap,
  });

  final String option;
  final _TileState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color? borderColor = switch (state) {
      _TileState.correct => ZovaColors.success,
      _TileState.wrong => ZovaColors.error,
      _ => null,
    };
    final Color background = switch (state) {
      _TileState.correct => ZovaColors.success.withValues(alpha: 0.12),
      _TileState.wrong => ZovaColors.error.withValues(alpha: 0.12),
      _TileState.dimmed => ZovaColors.surface.withValues(alpha: 0.6),
      _TileState.idle => ZovaColors.surface,
    };

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: state == _TileState.idle ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: borderColor == null
                ? Border.all(color: ZovaColors.surfaceRaised)
                : Border.all(color: borderColor, width: 1.5),
          ),
          child: Text(
            option,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
