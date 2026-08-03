import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/ui_translation_controller.dart';
import '../../../../core/theme/zova_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/tr_text.dart';
import '../../../../data/models/exercise.dart';

/// Typing exercise: enter the translation of the shown word.
class TranslateView extends StatefulWidget {
  const TranslateView({
    super.key,
    required this.exercise,
    required this.onDone,
  });

  final Exercise exercise;
  final ValueChanged<bool> onDone;

  @override
  State<TranslateView> createState() => _TranslateViewState();
}

class _TranslateViewState extends State<TranslateView> {
  final _controller = TextEditingController();
  String? _resultMessage;
  bool? _isCorrect;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    final answer = _controller.text.trim().toLowerCase();
    final expected = (widget.exercise.correctAnswer ?? '').trim().toLowerCase();
    final correct = answer.isNotEmpty && answer == expected;

    setState(() {
      _isCorrect = correct;
      _resultMessage = correct
          ? context.tr('Correct!')
          : context.trTempl('The answer is "{0}".', [
              widget.exercise.correctAnswer ?? '',
            ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final answered = _isCorrect != null;
    context.watch<UiTranslationController?>();
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
          TextField(
            controller: _controller,
            enabled: !answered,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(
              labelText: context.tr('Type the translation'),
              hintText: 'e.g. سلام',
            ),
          ),
          const SizedBox(height: 16),
          if (_resultMessage != null)
            Text(
              _resultMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isCorrect! ? ZovaColors.success : ZovaColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          const SizedBox(height: 16),
          if (!answered)
            GradientButton(
              label: context.tr('Check'),
              icon: Icons.check,
              onPressed: _check,
            )
          else
            GradientButton(
              label: context.tr('Continue'),
              icon: Icons.arrow_forward,
              onPressed: () => widget.onDone(_isCorrect!),
            ),
        ],
      ),
    );
  }
}
