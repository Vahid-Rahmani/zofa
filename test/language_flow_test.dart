import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/models/course.dart';
import 'package:zova/data/models/exercise.dart';
import 'package:zova/data/models/learning_state.dart';
import 'package:zova/data/models/user_progress.dart';
import 'package:zova/data/services/dictionary_service.dart';
import 'package:zova/data/services/german_frequency.dart';
import 'package:zova/data/services/seed_content.dart';
import 'package:zova/data/services/spaced_repetition.dart';
import 'package:zova/features/courses/courses_screen.dart';
import 'package:zova/features/dictionary/dictionary_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Serve the bundled dictionaries synchronously so widget tests have no
    // pending asset I/O under the fake async clock.
    DictionaryService.seedAsset(
      'assets/dictionary/english.json',
      await File('assets/dictionary/english.json').readAsString(),
    );
    DictionaryService.seedAsset(
      'assets/dictionary/german.json',
      await File('assets/dictionary/german.json').readAsString(),
    );
    GermanFrequencyList.seedAsset(
      GermanFrequencyList.assetPath,
      await File('assets/dictionary/german_top_50k.json').readAsString(),
    );
  });

  group('SeedContent.courseFor', () {
    test('returns the English course for en', () async {
      final course = await SeedContent.courseFor('en');
      expect(course, isNotNull);
      expect(course!.language, 'English');
      expect(course.levels.map((l) => l.level), ['A1', 'A2', 'B1']);
    });

    test('returns the German course for de', () async {
      final course = await SeedContent.courseFor('de');
      expect(course, isNotNull);
      expect(course!.language, 'German');
      expect(course.levels.map((l) => l.level), ['A1', 'A2', 'B1']);
      for (final level in course.levels) {
        expect(level.lessons.length, greaterThanOrEqualTo(9),
            reason: '${level.level} should have at least 9 lessons, '
                'found ${level.lessons.length}');
      }
    });

    test('the German course is built from the German dataset, not English', () async {
      final german = (await SeedContent.courseFor('de'))!;
      final english = (await SeedContent.courseFor('en'))!;

      final germanWords = _flashcardWords(german);
      expect(germanWords, isNotEmpty);
      expect(germanWords, contains('hallo'),
          reason: 'A1 greetings should be German words, got $germanWords');
      expect(germanWords, isNot(contains('hello')));

      final englishWords = _flashcardWords(english);
      expect(englishWords, contains('hello'));
      expect(englishWords, isNot(contains('hallo')));
    });

    test('every German exercise is well-formed', () async {
      final course = (await SeedContent.courseFor('de'))!;
      final allExercises = [
        for (final level in course.levels)
          for (final lesson in level.lessons) ...lesson.exercises,
      ];
      expect(allExercises, isNotEmpty);

      for (final exercise in allExercises) {
        switch (exercise.type) {
          case ExerciseType.chooseAnswer:
            expect(exercise.options.length, greaterThanOrEqualTo(2));
            expect(exercise.options, contains(exercise.correctAnswer));
          case ExerciseType.translate:
            expect(exercise.correctAnswer, isNotNull);
          case ExerciseType.pairs:
            expect(exercise.pairs.length, greaterThanOrEqualTo(2));
            for (final pair in exercise.pairs.entries) {
              expect(pair.value, isNotEmpty,
                  reason: '${pair.key} should pair with a non-empty example');
            }
          case ExerciseType.flashcard:
            expect(exercise.words, isNotEmpty);
            for (final word in exercise.words) {
              expect(exercise.examples[word], isNotEmpty,
                  reason: '$word should have an example sentence');
            }
          case ExerciseType.article:
            expect(exercise.options, contains(exercise.correctAnswer));
            expect(exercise.options.toSet(), containsAll(['der', 'die', 'das']));
        }
      }
    });

    test('unsupported languages complete with null (coming soon)', () async {
      expect(await SeedContent.courseFor('es'), isNull);
      expect(await SeedContent.courseFor('fr'), isNull);
    });

    test('courses are memoised per language', () async {
      expect(
        await SeedContent.englishCourse(),
        same(await SeedContent.englishCourse()),
      );
      expect(
        await SeedContent.courseFor('de'),
        same(await SeedContent.courseFor('de')),
      );
    });
  });

  group('UserProgress pair scoping', () {
    test('word progress is isolated per learning language', () {
      var progress = UserProgress();
      progress =
          progress.setLearningWord('de', 'Apfel', LearningState.legacy(box: 1));
      progress = progress.setLearningWord(
          'en', 'apple', LearningState.legacy(box: 2));
      progress = progress.setLearningWord(
          'es', 'manzana', LearningState.legacy(box: 3));

      expect(progress.learningFor('de').keys, ['Apfel']);
      expect(progress.learningFor('en').keys, ['apple']);
      expect(progress.learningFor('es').keys, ['manzana']);
      expect(progress.learningFor('de')['apple'], isNull);
      expect(progress.leitnerBoxesFor('de'), {'Apfel': 1});
      expect(progress.leitnerBoxesFor('en'), {'apple': 2});
    });

    test('lessons and saved words are scoped; switching back restores', () {
      var progress = UserProgress();
      progress = progress.addCompletedLesson('de', 'lesson_de_a1_greetings');
      progress = progress.addCompletedLesson('en', 'lesson_a1_greetings');
      progress = progress.addSavedWord('de', 'Apfel');
      progress = progress.addSavedWord('en', 'apple');

      expect(progress.completedLessonsFor('de'), ['lesson_de_a1_greetings']);
      expect(progress.completedLessonsFor('en'), ['lesson_a1_greetings']);
      expect(
        progress.completedLessonsFor('de'),
        isNot(contains('lesson_a1_greetings')),
      );
      expect(progress.savedWordsFor('de'), ['Apfel']);
      expect(progress.savedWordsFor('en'), ['apple']);
    });

    test('removing a word only affects its own language scope', () {
      var progress = UserProgress();
      progress =
          progress.setLearningWord('de', 'Apfel', LearningState.legacy(box: 2));
      progress = progress.setLearningWord(
          'en', 'apple', LearningState.legacy(box: 1));

      progress = progress.removeLearningWord('de', 'Apfel');

      expect(progress.learningFor('de'), isEmpty);
      expect(progress.learningFor('en').keys, ['apple']);
    });

    test('legacy flat progress migrates into the English scope', () {
      final state = LearningState.legacy(box: 3).toJson();
      final progress = UserProgress.fromJson({
        'xp': 50,
        'completed_lesson_ids': ['a', 'b'],
        'saved_words': ['apple'],
        'learning': {'apple': state},
      });

      expect(progress.completedLessonsFor('en'), ['a', 'b']);
      expect(progress.savedWordsFor('en'), ['apple']);
      expect(progress.learningFor('en').keys, ['apple']);
      expect(progress.learningFor('en')['apple']!.box, 3);
      expect(progress.learningFor('de'), isEmpty);
    });

    test('nested pair format round-trips through JSON', () {
      var progress = UserProgress();
      progress =
          progress.setLearningWord('de', 'Apfel', LearningState.legacy(box: 2));
      progress = progress.addSavedWord('de', 'Apfel');
      progress = progress.addCompletedLesson('de', 'lesson_de_a1_greetings');

      final restored = UserProgress.fromJson(progress.toJson());

      expect(restored.learningFor('de')['Apfel']!.box, 2);
      expect(restored.savedWordsFor('de'), ['Apfel']);
      expect(restored.completedLessonsFor('de'), ['lesson_de_a1_greetings']);
      expect(restored.learningFor('en'), isEmpty);
    });
  });

  group('AppController pair-scoped progress', () {
    testWidgets(
        'Leitner progress is isolated per pair, persisted, and restored on '
        'switch back', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final clock = DateTime(2026, 8, 2, 9);
      final language = LanguageController();
      final controller = AppController(
        language: language,
        scheduler: SpacedRepetitionScheduler(now: () => clock),
      );
      await controller.bootstrap();
      await controller.signUp(
        email: 'pair@example.com',
        password: 'secret123',
      );
      expect(controller.user, isNotNull);

      // Learning German: Apfel enters the German scope only.
      await language.setLearningLanguage('de');
      await controller.addToLeitner('Apfel');
      expect(controller.learningState('Apfel'), isNotNull);

      // Learning English: the German word must not leak across pairs.
      await language.setLearningLanguage('en');
      expect(controller.learningState('Apfel'), isNull,
          reason: 'a German word must not appear in the English scope');
      await controller.addToLeitner('apple');
      expect(controller.progress.learningFor('en').keys, ['apple']);
      expect(controller.progress.learningFor('de').keys, ['Apfel']);

      // A fresh session (restart) restores both scopes from disk.
      final restoredLanguage = LanguageController(initial: language.settings);
      final restored = AppController(
        language: restoredLanguage,
        scheduler: SpacedRepetitionScheduler(now: () => clock),
      );
      await restored.bootstrap();
      expect(restored.user, isNotNull);
      expect(restored.progress.learningFor('de').keys, ['Apfel']);
      expect(restored.progress.learningFor('en').keys, ['apple']);

      // Switching back to German restores the old state untouched.
      await language.setLearningLanguage('de');
      expect(controller.learningState('Apfel')!.box, 1);
      expect(controller.progress.learningFor('en').keys, ['apple']);
    });

    testWidgets('saved words and completed lessons follow the active pair',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final language = LanguageController();
      final controller = AppController(language: language);
      await controller.bootstrap();
      await controller.signUp(
        email: 'words@example.com',
        password: 'secret123',
      );

      await language.setLearningLanguage('de');
      await controller.saveWord('Apfel');
      await controller.completeLesson(
        lessonId: 'lesson_de_a1_greetings',
        xpEarned: 20,
        wordsEarned: 8,
      );

      await language.setLearningLanguage('en');
      expect(controller.progress.savedWordsFor('en'), isEmpty);
      expect(controller.progress.completedLessonsFor('en'), isEmpty);

      await controller.saveWord('apple');
      await controller.completeLesson(
        lessonId: 'lesson_a1_greetings',
        xpEarned: 20,
        wordsEarned: 8,
      );

      expect(controller.progress.savedWordsFor('de'), ['Apfel']);
      expect(controller.progress.savedWordsFor('en'), ['apple']);
      expect(
        controller.progress.completedLessonsFor('de'),
        ['lesson_de_a1_greetings'],
      );
      expect(
        controller.progress.completedLessonsFor('en'),
        ['lesson_a1_greetings'],
      );
    });
  });

  group('UI reactivity to the language pair', () {
    testWidgets('the Courses tab swaps roadmap with the learning language',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      // The course cache may have been warmed by the real-async unit tests
      // above; that completed future never delivers under the fake async clock,
      // so reload the course fresh inside this test's zone.
      SeedContent.resetCourses();
      final language = LanguageController();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: language),
            ChangeNotifierProvider(
              create: (_) => AppController(language: language),
            ),
          ],
          child: const MaterialApp(home: CoursesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Learn English'), findsOneWidget);

      await language.setLearningLanguage('de');
      await tester.pumpAndSettle();
      expect(find.text('Learn German'), findsOneWidget);
      expect(find.text('Foundations'), findsOneWidget);

      await language.setLearningLanguage('es');
      await tester.pumpAndSettle();
      expect(find.text('Spanish course coming soon'), findsOneWidget);
    });

    testWidgets('the Dictionary pickers follow the saved language pair',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final language = LanguageController();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: language),
            ChangeNotifierProvider(
              create: (_) => AppController(language: language),
            ),
          ],
          child: const MaterialApp(home: DictionaryScreen()),
        ),
      );
      await tester.pump();

      // Default pair: English -> Persian.
      expect(find.text('English (en)'), findsOneWidget);
      expect(find.text('فارسی (fa)'), findsOneWidget);

      // Switching the pair re-anchors the pickers without a restart.
      await language.setLearningLanguage('de');
      await tester.pump();
      expect(find.text('Deutsch (de)'), findsOneWidget);
      expect(find.text('English (en)'), findsNothing);
      expect(find.text('فارسی (fa)'), findsOneWidget);
    });
  });
}

Set<String> _flashcardWords(Course course) => {
      for (final level in course.levels)
        for (final lesson in level.lessons)
          for (final exercise in lesson.exercises)
            if (exercise.type == ExerciseType.flashcard) ...exercise.words,
    };
