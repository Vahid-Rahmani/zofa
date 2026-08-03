import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_controller.dart';
import '../../../core/state/ui_translation_controller.dart';
import '../../../core/theme/zova_colors.dart';
import '../../../core/widgets/tr_text.dart';
import '../../../data/models/exercise.dart';
import '../../gamification/hearts_bar.dart';
import 'exercises/article_view.dart';
import 'exercises/choose_answer_view.dart';
import 'exercises/flashcard_view.dart';
import 'exercises/pairs_view.dart';
import 'exercises/translate_view.dart';
import '../lesson_result/lesson_result_screen.dart';
import '../../../data/models/course.dart';

/// Plays the exercises of a single [Lesson] one by one and reports the
/// outcome back to the progress store.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    required this.onComplete,
  });

  final Lesson lesson;
  final VoidCallback onComplete;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _index = 0;
  int _correct = 0;
  bool _leaving = false;

  Exercise get _current => widget.lesson.exercises[_index];

  void _handleResult({required bool correct}) {
    if (correct) {
      _correct++;
    } else {
      context.read<AppController>().consumeHeart();
    }
    if (_index < widget.lesson.exercises.length - 1) {
      setState(() => _index++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _leaving = true);
    final lessonWords = <String>{
      for (final exercise in widget.lesson.exercises) ...exercise.words,
    };
    final words = lessonWords.length;
    final xp = 10 * widget.lesson.exercises.length + _correct * 5;

    final controller = context.read<AppController>();
    final boosted = controller.boostActive;
    await controller.completeLesson(
      lessonId: widget.lesson.id,
      xpEarned: xp,
      wordsEarned: words,
    );
    // Every word studied in the lesson joins the Leitner review deck (scoped
    // to the active learning language) so flashcards and spaced repetition
    // always practice exactly the words the lesson taught.
    await controller.addWordsToLeitner(lessonWords.toList());

    if (!mounted) return;
    widget.onComplete();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LessonResultScreen(
          lessonTitle: widget.lesson.title,
          correct: _correct,
          total: widget.lesson.exercises.length,
          xp: boosted ? xp * 2 : xp,
          words: words,
          boosted: boosted,
        ),
      ),
    );
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Leave lesson?')),
        content: Text(context.tr('Your progress in this lesson will be lost.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Keep learning')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Leave')),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _current;
    final progress = (_index + 1) / widget.lesson.exercises.length;
    context.watch<UiTranslationController?>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _leaving ? null : _confirmExit,
        ),
        title: Text(
          '${_index + 1}/${widget.lesson.exercises.length}',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: HeartsBar()),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: ZovaColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ZovaColors.primary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Text(widget.lesson.icon,
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      exercise.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: switch (exercise.type) {
                  ExerciseType.flashcard => FlashcardView(
                      exercise: exercise,
                      onDone: (correct) => _handleResult(correct: correct),
                    ),
                  ExerciseType.chooseAnswer => ChooseAnswerView(
                      exercise: exercise,
                      onDone: (correct) => _handleResult(correct: correct),
                    ),
                  ExerciseType.translate => TranslateView(
                      exercise: exercise,
                      onDone: (correct) => _handleResult(correct: correct),
                    ),
                  ExerciseType.pairs => PairsView(
                      exercise: exercise,
                      onDone: (correct) => _handleResult(correct: correct),
                    ),
                  ExerciseType.article => ArticleView(
                      exercise: exercise,
                      onDone: (correct) => _handleResult(correct: correct),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
