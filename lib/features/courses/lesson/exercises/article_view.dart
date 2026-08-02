import 'package:flutter/material.dart';

import '../../../../core/theme/zova_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../data/models/exercise.dart';

/// German article quiz: pick the grammatical article (`der`/`die`/`das`) for
/// a shown noun.
class ArticleView extends StatefulWidget {
  const ArticleView({
    super.key,
    required this.exercise,
    required this.onDone,
  });

  final Exercise exercise;
  final ValueChanged<bool> onDone;

  @override
  State<ArticleView> createState() => _ArticleViewState();
}

class _ArticleViewState extends State<ArticleView> {
  String? _selected;
  bool _answered = false;

  void _choose(String article) {
    if (_answered) return;
    setState(() {
      _selected = article;
      _answered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(widget.exercise.options)
      ..sort();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Which article does this noun take?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ZovaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _noun,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final option in options) ...[
            _ArticleTile(
              article: option,
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

  String get _noun {
    final match = RegExp(r'^«([^»]*)»').firstMatch(widget.exercise.prompt);
    return match?.group(1)?.trim() ?? widget.exercise.prompt;
  }

  _TileState _stateFor(String article) {
    if (!_answered) return _TileState.idle;
    if (article == widget.exercise.correctAnswer) return _TileState.correct;
    if (article == _selected) return _TileState.wrong;
    return _TileState.dimmed;
  }
}

enum _TileState { idle, correct, wrong, dimmed }

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.state,
    required this.onTap,
  });

  final String article;
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
            article,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ZovaColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
