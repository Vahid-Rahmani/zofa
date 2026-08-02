/// A single vocabulary entry in the built-in English -> Persian dictionary.
///
/// Mirrors the teaching style of B-Amooz: every word ships with an accurate
/// translation, a real example sentence, and a proficiency level so the same
/// data powers the dictionary, the courses and the in-reader lookups.
class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.translation,
    required this.partOfSpeech,
    required this.level,
    required this.example,
    required this.exampleTranslation,
    this.phonetic,
    this.gender,
    this.topics = const [],
  });

  /// The headword (lowercase for English, capitalised for German nouns).
  final String word;

  /// Accurate Persian (Farsi) translation.
  final String translation;

  /// Part of speech, e.g. `noun`, `verb`, `adjective`, `phrase`.
  final String partOfSpeech;

  /// CEFR proficiency level: `A1`, `A2` or `B1`.
  final String level;

  /// Practical example sentence showing real usage.
  final String example;

  /// Persian translation of [example].
  final String exampleTranslation;

  /// Optional IPA-ish pronunciation hint.
  final String? phonetic;

  /// Grammatical gender of German nouns (`der`, `die`, `das`); `null` for
  /// words without a gender.
  final String? gender;

  /// Topic tags used to build lessons, e.g. `greetings`, `travel`.
  final List<String> topics;

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] as String,
      translation: json['translation'] as String,
      partOfSpeech: json['part_of_speech'] as String,
      level: json['level'] as String,
      example: json['example'] as String,
      exampleTranslation: json['example_translation'] as String,
      phonetic: json['phonetic'] as String?,
      gender: json['gender'] as String?,
      topics: (json['topics'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'translation': translation,
        'part_of_speech': partOfSpeech,
        'level': level,
        'example': example,
        'example_translation': exampleTranslation,
        'phonetic': phonetic,
        'gender': gender,
        'topics': topics,
      };
}
