import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/data/models/learning_state.dart';
import 'package:zova/data/models/user_progress.dart';
import 'package:zova/data/services/spaced_repetition.dart';

void main() {
  group('SpacedRepetitionScheduler', () {
    late DateTime now;
    late SpacedRepetitionScheduler scheduler;

    setUp(() {
      now = DateTime(2026, 8, 2, 9);
      scheduler = SpacedRepetitionScheduler(now: () => now);
    });

    test('new state is box 1, newWord, due immediately', () {
      final state = scheduler.newState();
      expect(state.box, 1);
      expect(state.stage, LearningStage.newWord);
      expect(state.repetitions, 0);
      expect(state.intervalDays, 0);
      expect(state.ease, 2.5);
      expect(state.correctCount, 0);
      expect(state.incorrectCount, 0);
      expect(state.isDueAt(now), isTrue);
      // A word stays due once its due date has passed.
      expect(state.isDueAt(now.add(const Duration(days: 1))), isTrue);

      // A word scheduled for tomorrow is not due today.
      final scheduled = scheduler.review(state, knew: true);
      expect(scheduled.isDueAt(now), isFalse);
      expect(
        scheduled.isDueAt(now.add(const Duration(days: 1))),
        isTrue,
      );
    });

    test('first success: learning stage, 1-day interval, box 2', () {
      final state = scheduler.review(scheduler.newState(), knew: true);
      expect(state.stage, LearningStage.learning);
      expect(state.repetitions, 1);
      expect(state.intervalDays, 1);
      expect(state.box, 2);
      expect(state.due, now.add(const Duration(days: 1)));
      expect(state.correctCount, 1);
      expect(state.lastReviewed, now);
    });

    test('SM-2 intervals grow 1, 6, then ease-scaled to mastery', () {
      var state = scheduler.newState();
      state = scheduler.review(state, knew: true);
      expect(state.intervalDays, 1);

      state = scheduler.review(state, knew: true);
      expect(state.intervalDays, 6);
      expect(state.box, 3);
      expect(state.stage, LearningStage.learning);

      state = scheduler.review(state, knew: true);
      expect(state.intervalDays, (6 * 2.5).round());
      expect(state.stage, LearningStage.review);

      state = scheduler.review(state, knew: true);
      expect(state.intervalDays, greaterThanOrEqualTo(21));
      expect(state.stage, LearningStage.mastered);
    });

    test('failure resets to box 1, keeps word due today for retry', () {
      var state = scheduler.newState();
      state = scheduler.review(state, knew: true);
      state = scheduler.review(state, knew: true);
      expect(state.box, 3);

      final failed = scheduler.review(state, knew: false);
      expect(failed.box, 1);
      expect(failed.repetitions, 0);
      expect(failed.intervalDays, 1);
      expect(failed.stage, LearningStage.learning);
      expect(failed.incorrectCount, 1);
      expect(failed.isDueAt(now), isTrue);
      expect(failed.due, now);
    });

    test('ease is bounded to the SM-2 range', () {
      var state = scheduler.newState();
      for (var i = 0; i < 20; i++) {
        state = scheduler.review(state, knew: true);
        expect(state.ease, lessThanOrEqualTo(SpacedRepetitionScheduler.maxEase));
      }
      for (var i = 0; i < 20; i++) {
        state = scheduler.review(state, knew: false);
        expect(
          state.ease,
          greaterThanOrEqualTo(SpacedRepetitionScheduler.minEase),
        );
      }
      expect(state.box, 1);
    });

    test('box never exceeds the max', () {
      var state = scheduler.newState();
      for (var i = 0; i < 10; i++) {
        state = scheduler.review(state, knew: true);
      }
      expect(state.box, SpacedRepetitionScheduler.maxBox);
      expect(state.stage, LearningStage.mastered);
    });

    test('dueQueue only includes due cards, most urgent first', () {
      final fresh = scheduler.newState(); // due == now
      final scheduled = scheduler.review(fresh, knew: true); // due == now + 1d

      expect(scheduler.dueQueue([fresh, scheduled]).length, 1);

      now = now.add(const Duration(hours: 12));
      expect(scheduler.dueQueue([fresh, scheduled]).length, 1);

      now = now.add(const Duration(hours: 24));
      expect(scheduler.dailyDueCount([fresh, scheduled]), 2);
      final queue = scheduler.dueQueue([scheduled, fresh]);
      expect(queue.length, 2);
      expect(queue.first, same(fresh), reason: 'older due date queues first');
    });
  });

  group('UserProgress learning state', () {
    test('legacy leitner_boxes migrate to learning states on load', () {
      final progress = UserProgress.fromJson({
        'xp': 0,
        'leitner_boxes': {'apple': 1, 'book': 3},
      });
      expect(progress.learning.length, 2);
      expect(progress.leitnerBoxes, {'apple': 1, 'book': 3});
      expect(progress.learning['apple']!.box, 1);
      expect(
        progress.learning['book']!.isDueAt(DateTime(2026, 1, 1)),
        isTrue,
        reason: 'migrated words are immediately reviewable',
      );
    });

    test('learning states round-trip through JSON', () {
      final progress = UserProgress(
        savedWords: ['apple'],
        learning: {
          'apple': LearningState(
            box: 3,
            stage: LearningStage.review,
            repetitions: 3,
            intervalDays: 15,
            ease: 2.5,
            due: DateTime(2026, 8, 17),
            lastReviewed: DateTime(2026, 8, 2),
            correctCount: 5,
            incorrectCount: 1,
          ),
        },
      );

      final restored = UserProgress.fromJson(progress.toJson());
      final state = restored.learning['apple']!;
      expect(state.box, 3);
      expect(state.stage, LearningStage.review);
      expect(state.repetitions, 3);
      expect(state.intervalDays, 15);
      expect(state.ease, 2.5);
      expect(state.due, DateTime(2026, 8, 17));
      expect(state.lastReviewed, DateTime(2026, 8, 2));
      expect(state.correctCount, 5);
      expect(state.incorrectCount, 1);
      expect(restored.leitnerBoxes, {'apple': 3});
    });

    test('constructor leitnerBoxes seeds learning with legacy states', () {
      final progress = UserProgress(leitnerBoxes: {'apple': 1, 'book': 5});
      expect(progress.learning['apple']!.box, 1);
      expect(progress.learning['book']!.stage, LearningStage.review);
      expect(progress.leitnerBoxes, {'apple': 1, 'book': 5});
    });
  });

  group('AppController integration', () {
    testWidgets('addToLeitner and reviewLeitnerCard drive the scheduler',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      var clock = DateTime(2026, 8, 2, 9);
      final controller = AppController(
        scheduler: SpacedRepetitionScheduler(now: () => clock),
      );
      await controller.bootstrap();
      await controller.signUp(
        email: 'learner@example.com',
        password: 'secret123',
      );

      expect(controller.user, isNotNull);

      await controller.addToLeitner('apple');
      var state = controller.learningState('apple')!;
      expect(state.box, 1);
      expect(state.stage, LearningStage.newWord);
      expect(state.due, clock);

      // Adding twice is a no-op.
      await controller.addToLeitner('apple');
      expect(controller.progress.learning.length, 1);

      await controller.reviewLeitnerCard('apple', knew: true);
      state = controller.learningState('apple')!;
      expect(state.box, 2);
      expect(state.intervalDays, 1);
      expect(state.correctCount, 1);

      // The word is not due until tomorrow.
      clock = clock.add(const Duration(hours: 12));
      expect(controller.scheduler.dailyDueCount(controller.progress.learning.values), 0);
      clock = clock.add(const Duration(hours: 12));
      expect(controller.scheduler.dailyDueCount(controller.progress.learning.values), 1);

      // A failed review resets the word and keeps it due today.
      await controller.reviewLeitnerCard('apple', knew: false);
      state = controller.learningState('apple')!;
      expect(state.box, 1);
      expect(state.incorrectCount, 1);
      expect(controller.scheduler.isDue(state), isTrue);

      await controller.removeFromLeitner('apple');
      expect(controller.learningState('apple'), isNull);

      // Reviewing an unknown word still records the answer.
      await controller.reviewLeitnerCard('orange', knew: true);
      expect(controller.learningState('orange')!.box, 2);
    });
  });
}
