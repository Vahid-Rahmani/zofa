import 'exercise.dart';

/// Converts [Exercise] to and from its JSON representation so that courses
/// can be shipped as plain asset files and, later, served by the backend.
abstract final class ExerciseParser {
  static Exercise fromJson(Map<String, dynamic> json) {
    final type = ExerciseType.values.byName(json['type'] as String);
    return Exercise(
      type: type,
      prompt: (json['prompt'] as String?) ?? '',
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      correctAnswer: json['correct_answer'] as String?,
      pairs: (json['pairs'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, value as String),
      ),
      words: (json['words'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }

  static Map<String, dynamic> toJson(Exercise e) {
    return {
      'type': e.type.name,
      'prompt': e.prompt,
      'options': e.options,
      'correct_answer': e.correctAnswer,
      'pairs': e.pairs,
      'words': e.words,
    };
  }
}
