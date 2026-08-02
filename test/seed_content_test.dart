import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/exercise.dart';
import 'package:zova/data/services/seed_content.dart';

void main() {
  group('SeedContent integrity', () {
    test('exposes a single course with A1, A2 and B1 levels in order', () {
      expect(SeedContent.courses, hasLength(1));
      final course = SeedContent.courses.first;

      expect(course.levels.map((l) => l.level), ['A1', 'A2', 'B1']);
      expect(course.language, 'English');
      expect(course.nativeLanguage, 'Persian');

      for (final level in course.levels) {
        expect(level.lessons.length, greaterThanOrEqualTo(9),
            reason: '${level.level} should have at least 9 lessons, '
                'found ${level.lessons.length}');
      }
    });

    test('every course lesson exercise is well-formed', () {
      final allExercises = SeedContent.courses
          .expand((course) => course.levels)
          .expand((level) => level.lessons)
          .expand((lesson) => lesson.exercises)
          .toList();

      expect(allExercises, isNotEmpty);

      for (final exercise in allExercises) {
        switch (exercise.type) {
          case ExerciseType.chooseAnswer:
            expect(exercise.options.length, greaterThanOrEqualTo(2));
            expect(exercise.correctAnswer, isNotNull);
            expect(exercise.options, contains(exercise.correctAnswer));
          case ExerciseType.translate:
            expect(exercise.correctAnswer, isNotNull);
          case ExerciseType.pairs:
            expect(exercise.pairs.length, greaterThanOrEqualTo(2));
          case ExerciseType.flashcard:
            expect(exercise.words, isNotEmpty);
            expect(exercise.pairs.keys.toSet(), containsAll(exercise.words));
            expect(exercise.examples.keys.toSet(), containsAll(exercise.words));
            for (final word in exercise.words) {
              expect(exercise.examples[word], isNotEmpty,
                  reason: '$word should have an example sentence');
            }
        }
      }
    });

    test('course vocabulary covers hundreds of distinct words', () {
      final words = <String>{};
      for (final course in SeedContent.courses) {
        for (final level in course.levels) {
          for (final lesson in level.lessons) {
            for (final exercise in lesson.exercises) {
              if (exercise.type == ExerciseType.flashcard) {
                words.addAll(exercise.words);
              }
            }
          }
        }
      }

      expect(words.length, greaterThanOrEqualTo(180),
          reason: 'expected hundreds of vocabulary words, found ${words.length}');
    });

    test('every book has chapters with text and Persian translation', () {
      expect(SeedContent.books.length, greaterThanOrEqualTo(9));

      for (final book in SeedContent.books) {
        expect(['A1', 'A2', 'B1'], contains(book.level),
            reason: '${book.id} should carry a valid CEFR level');
        expect(book.chapters, isNotEmpty);
        for (final chapter in book.chapters) {
          expect(chapter.paragraphs, isNotEmpty);
          for (final paragraph in chapter.paragraphs) {
            expect(paragraph.text, isNotEmpty);
            expect(paragraph.translation, isNotNull);
            expect(paragraph.translation, isNotEmpty);
          }
        }
      }
    });
  });
}
