import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/exercise.dart';
import 'package:zova/data/models/exercise_parser.dart';

void main() {
  group('ExerciseParser', () {
    test('round-trips every exercise type', () {
      final exercises = [
        const Exercise(
          type: ExerciseType.chooseAnswer,
          prompt: 'What does "two" mean?',
          options: ['Eins', 'Zwei'],
          correctAnswer: 'Zwei',
        ),
        const Exercise(
          type: ExerciseType.translate,
          prompt: 'Translate "yes"',
          correctAnswer: 'ja',
        ),
        const Exercise(
          type: ExerciseType.pairs,
          prompt: 'Match the pairs',
          pairs: {'one': 'eins', 'two': 'zwei'},
        ),
        const Exercise(
          type: ExerciseType.flashcard,
          prompt: 'Learn these words',
          words: ['hello', 'goodbye'],
          pairs: {'hello': 'hallo', 'goodbye': 'auf Wiedersehen'},
          examples: {'hello': 'Hello, how are you?', 'goodbye': 'Goodbye!'},
        ),
      ];

      for (final exercise in exercises) {
        final restored = ExerciseParser.fromJson(ExerciseParser.toJson(exercise));
        expect(restored.type, exercise.type);
        expect(restored.prompt, exercise.prompt);
        expect(restored.options, exercise.options);
        expect(restored.correctAnswer, exercise.correctAnswer);
        expect(restored.pairs, exercise.pairs);
        expect(restored.words, exercise.words);
        expect(restored.examples, exercise.examples);
      }
    });
  });
}
