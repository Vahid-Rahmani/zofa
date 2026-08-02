import '../services/normalize.dart' as normalize;

/// A single vocabulary entry in a bundled source-language -> Persian
/// dictionary (English, German, and later Spanish / French / Italian).
///
/// Mirrors the teaching style of B-Amooz: every word ships with an accurate
/// translation, a real example sentence, and a CEFR proficiency level so the
/// same data powers the dictionary, the courses and the in-reader lookups.
///
/// The schema is intentionally permissive: only [word], [translation],
/// [partOfSpeech] and [level] are required for an entry to be valid. Every
/// other field is optional linguistic metadata, so the loader can ingest a
/// wide range of open-source dumps and "gracefully" skip malformed rows
/// (see [tryParse] and [validate]).
class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.translation,
    required this.partOfSpeech,
    required this.level,
    this.example = '',
    this.exampleTranslation = '',
    this.id,
    this.lemma,
    this.language,
    this.phonetic,
    this.gender,
    this.plural,
    this.synonyms = const [],
    this.antonyms = const [],
    this.relatedWords = const [],
    this.irregularForms = const [],
    this.alternateTranslations = const [],
    this.topics = const [],
    this.tags = const [],
    this.frequency,
    this.audioRef,
    this.imageRef,
  });

  /// The headword (lowercase for English, capitalised for German nouns).
  final String word;

  /// Accurate Persian (Farsi) translation (the primary translation).
  final String translation;

  /// Part of speech, e.g. `noun`, `verb`, `adjective`, `phrase`.
  final String partOfSpeech;

  /// CEFR proficiency level (`A1` ... `C2`). Serves as the difficulty level
  /// too; a separate difficulty field would duplicate this information.
  final String level;

  /// Practical example sentence showing real usage (empty when a dump does
  /// not ship examples).
  final String example;

  /// Persian translation of [example].
  final String exampleTranslation;

  /// Stable unique identifier. May be absent in legacy curated assets, in
  /// which case [effectiveId] falls back to a deterministic slug of [word].
  final String? id;

  /// Base/canonical form (German verbs -> infinitive, nouns -> nominative
  /// singular). Falls back to [word] via [effectiveLemma].
  final String? lemma;

  /// ISO 639-1 source language code, e.g. `en`, `de`, `es`.
  final String? language;

  /// Optional IPA-ish pronunciation hint.
  final String? phonetic;

  /// Grammatical gender of nouns (`der`, `die`, `das` for German, `masculine`,
  /// `feminine`, `neuter` for Romance languages); `null` for words without a
  /// gender.
  final String? gender;

  /// Plural form where relevant (esp. German nouns).
  final String? plural;

  /// Synonym headwords in the source language.
  final List<String> synonyms;

  /// Antonym headwords in the source language.
  final List<String> antonyms;

  /// Related words (derived terms, collocations) in the source language.
  final List<String> relatedWords;

  /// Irregular forms, e.g. German verb principal parts.
  final List<String> irregularForms;

  /// Additional accepted translations beyond [translation].
  final List<String> alternateTranslations;

  /// Topic tags used to build lessons, e.g. `greetings`, `travel`.
  final List<String> topics;

  /// Extra free-form tags, e.g. register (`formal`, `informal`) or `irregular`.
  final List<String> tags;

  /// Corpus frequency score (higher = more common), when the source dump
  /// provides one. `null` for curated entries without frequency data.
  final int? frequency;

  /// Reference to a bundled audio asset or remote audio key, when available.
  final String? audioRef;

  /// Reference to a bundled image asset or remote image key, when available.
  final String? imageRef;

  /// The identifier used by the dictionary engine and index: [id] when the
  /// entry carries one, otherwise a deterministic slug of [word].
  String get effectiveId => id ?? slug(word);

  /// [lemma] when provided, otherwise [word].
  String get effectiveLemma => lemma ?? word;

  /// Builds a deterministic, filesystem- and JSON-safe slug from [word]
  /// (e.g. `Good morning` -> `good-morning`). Headwords are unique, so slugs
  /// are unique too.
  static String slug(String word) => normalize.slug(word);

  /// Validates a raw [json] map and returns a list of human-readable problems.
  /// An empty list means the map is a valid entry.
  static List<String> validate(Map<String, dynamic> json) {
    final errors = <String>[];
    if ((json['word'] as String? ?? '').trim().isEmpty) {
      errors.add('missing or empty "word"');
    }
    if ((json['translation'] as String? ?? '').trim().isEmpty) {
      errors.add('missing or empty "translation"');
    }
    if ((json['part_of_speech'] as String? ?? '').trim().isEmpty) {
      errors.add('missing or empty "part_of_speech"');
    }
    if ((json['level'] as String? ?? '').trim().isEmpty) {
      errors.add('missing or empty "level"');
    }
    return errors;
  }

  /// Parses [json] when it is a valid entry, otherwise returns `null` so
  /// loaders can skip malformed rows without crashing the application.
  static DictionaryEntry? tryParse(Map<String, dynamic> json) {
    if (validate(json).isNotEmpty) return null;
    return DictionaryEntry.fromJson(json);
  }

  /// Strict parse used when an entry is known to be well-formed (e.g. inside
  /// [tryParse] or when round-tripping our own [toJson]). Throws
  /// [FormatException] with the full list of problems for malformed maps.
  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    final errors = validate(json);
    if (errors.isNotEmpty) {
      throw FormatException('Invalid dictionary entry: ${errors.join('; ')}');
    }
    return DictionaryEntry(
      word: json['word'] as String,
      translation: json['translation'] as String,
      partOfSpeech: json['part_of_speech'] as String,
      level: json['level'] as String,
      example: json['example'] as String? ?? '',
      exampleTranslation: json['example_translation'] as String? ?? '',
      id: json['id'] as String?,
      lemma: json['lemma'] as String?,
      language: json['language'] as String?,
      phonetic: json['phonetic'] as String?,
      gender: json['gender'] as String?,
      plural: json['plural'] as String?,
      synonyms: _listOf(json, 'synonyms'),
      antonyms: _listOf(json, 'antonyms'),
      relatedWords: _listOf(json, 'related_words'),
      irregularForms: _listOf(json, 'irregular_forms'),
      alternateTranslations: _listOf(json, 'alternate_translations'),
      topics: _listOf(json, 'topics'),
      tags: _listOf(json, 'tags'),
      frequency: (json['frequency'] as num?)?.toInt(),
      audioRef: json['audio_ref'] as String?,
      imageRef: json['image_ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': effectiveId,
        'word': word,
        'translation': translation,
        'part_of_speech': partOfSpeech,
        'level': level,
        'example': example,
        'example_translation': exampleTranslation,
        'lemma': lemma,
        'language': language,
        'phonetic': phonetic,
        'gender': gender,
        'plural': plural,
        'synonyms': synonyms,
        'antonyms': antonyms,
        'related_words': relatedWords,
        'irregular_forms': irregularForms,
        'alternate_translations': alternateTranslations,
        'topics': topics,
        'tags': tags,
        'frequency': frequency,
        'audio_ref': audioRef,
        'image_ref': imageRef,
      };

  static List<String> _listOf(Map<String, dynamic> json, String key) =>
      [for (final e in (json[key] as List<dynamic>? ?? const [])) e as String];
}
