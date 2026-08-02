import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/exercise.dart';
import 'package:zova/data/services/seed_content.dart';

void main() {
  group('SeedContent integrity', () {
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
        }
      }
    });

    test('every book has chapters with text', () {
      for (final book in SeedContent.books) {
        expect(book.chapters, isNotEmpty);
        for (final chapter in book.chapters) {
          expect(chapter.paragraphs, isNotEmpty);
          for (final paragraph in chapter.paragraphs) {
            expect(paragraph.text, isNotEmpty);
          }
        }
      }
    });
  });
}
