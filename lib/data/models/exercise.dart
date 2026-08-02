/// Every interactive element inside a lesson is one of these exercise types.
enum ExerciseType {
  /// Tap the correct translation for a given word.
  chooseAnswer,

  /// Type the translation of a shown word.
  translate,

  /// Match pairs of words and translations.
  pairs,

  /// Flip cards to study new vocabulary.
  flashcard,
}

/// A single step inside a lesson.
class Exercise {
  const Exercise({
    required this.type,
    required this.prompt,
    this.options = const [],
    this.correctAnswer,
    this.pairs = const {},
    this.words = const [],
    this.examples = const {},
  });

  final ExerciseType type;
  final String prompt;
  final List<String> options;
  final String? correctAnswer;

  /// Word -> translation pairs used by [ExerciseType.pairs].
  final Map<String, String> pairs;

  /// Words to study in a [ExerciseType.flashcard].
  final List<String> words;

  /// Word -> practical English example sentence shown on flashcards.
  final Map<String, String> examples;

  /// Human readable label used in the exercise header.
  String get title => switch (type) {
        ExerciseType.chooseAnswer => 'Choose the answer',
        ExerciseType.translate => 'Translate it',
        ExerciseType.pairs => 'Match the pairs',
        ExerciseType.flashcard => 'New words',
      };
}
