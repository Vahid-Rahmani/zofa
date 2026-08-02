import '../services/normalize.dart' as normalize;

/// A single vocabulary entry in a bundled multilingual dictionary.
///
/// Every entry models a full **3-way language bridge** so the same word can be
/// explained to a Persian speaker or an English speaker:
///
///   Target language (English / German) <-> English <-> Persian (فارسی)
///
/// * [word] — the headword in the target language.
/// * [translation] — the Persian gloss (canonical teaching translation).
/// * [englishTranslation] — the English gloss.
/// * [persianDefinition] / [englishDefinition] — a fuller meaning in each
///   explanation language.
/// * [example] — a contextual sentence in the target language, plus
///   [persianExample] / [englishExample] translations of that same sentence.
///
/// [concept] links the same idea across target languages (e.g. `apple`,
/// `der Apfel`), which is what makes the German and English dictionaries
/// symmetric: every concept exists in both.
///
/// Only [word], [translation], [englishTranslation], [partOfSpeech] and
/// [level] are required for an entry to be valid; everything else is optional
/// metadata, so the loader skips malformed rows gracefully (see [tryParse] and
/// [validate]).
class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.translation,
    this.englishTranslation = '',
    this.persianDefinition = '',
    this.englishDefinition = '',
    this.persianExample = '',
    this.englishExample = '',
    this.concept,
    required this.partOfSpeech,
    required this.level,
    this.example = '',
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

  /// The headword in the target language (lowercase for English, capitalised
  /// German nouns like `der Apfel`).
  final String word;

  /// Persian (فارسی) gloss — the canonical teaching translation.
  final String translation;

  /// English gloss, completing the target <-> English <-> Persian bridge.
  final String englishTranslation;

  /// Fuller Persian meaning / explanation of the word.
  final String persianDefinition;

  /// Fuller English meaning / explanation of the word.
  final String englishDefinition;

  /// Persian rendering of [example].
  final String persianExample;

  /// English rendering of [example].
  final String englishExample;

  /// Shared concept id linking the same idea across target-language
  /// dictionaries (e.g. `apple` in English and German). Falls back to
  /// [effectiveId] via [effectiveConcept].
  final String? concept;

  /// Part of speech, e.g. `noun`, `verb`, `adjective`, `phrase`.
  final String partOfSpeech;

  /// CEFR proficiency level (`A1` ... `C2`). Serves as the difficulty level
  /// too; a separate difficulty field would duplicate this information.
  final String level;

  /// Practical example sentence in the target language showing real usage.
  final String example;

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

  /// Grammatical gender of German nouns (`der`, `die`, `das`); `null` for
  /// words without a gender.
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

  // ---------------------------------------------------------------------------
  // Derived views
  // ---------------------------------------------------------------------------

  /// Persian gloss. Kept for readability next to [translation].
  String get persianTranslation => translation;

  /// Persian rendering of [example] (legacy alias).
  String get exampleTranslation => persianExample;

  /// The identifier used by the dictionary engine and index: [id] when the
  /// entry carries one, otherwise a deterministic slug of [word].
  String get effectiveId => id ?? slug(word);

  /// [concept] when provided, otherwise the deterministic slug of [word].
  String get effectiveConcept => concept ?? effectiveId;

  /// [lemma] when provided, otherwise [word].
  String get effectiveLemma => lemma ?? word;

  /// The gloss to show for the given explanation language `code`
  /// (`fa` / `fa-IR` -> Persian, anything else -> English, falling back to the
  /// Persian gloss when no English gloss is stored).
  String translationIn(String code) =>
      _isPersian(code) ? translation : _orEnglish(englishTranslation, translation);

  /// The meaning/definition to show for `code`.
  String definitionIn(String code) => _isPersian(code)
      ? _orEnglish(persianDefinition, translation)
      : _orEnglish(englishDefinition, _orEnglish(englishTranslation, translation));

  /// The example sentence to show for `code`: the target-language example when
  /// the request matches the entry's own language, otherwise the translation.
  String exampleIn(String code) {
    if (language == null || language == 'en' || language == 'de') {
      return _isPersian(code)
          ? _orEnglish(persianExample, example)
          : _orEnglish(englishExample, example);
    }
    return example;
  }

  static bool _isPersian(String code) => code == 'fa' || code == 'fa-IR';

  static String _orEnglish(String value, String fallback) =>
      value.isEmpty ? fallback : value;

  /// Builds a deterministic, filesystem- and JSON-safe slug from [word]
  /// (e.g. `Good morning` -> `good-morning`). Headwords are unique, so slugs
  /// are unique too.
  static String slug(String word) => normalize.slug(word);

  // ---------------------------------------------------------------------------
  // Serialisation & validation
  // ---------------------------------------------------------------------------

  /// Validates a raw [json] map and returns a list of human-readable problems.
  /// An empty list means the map is a valid multilingual entry.
  static List<String> validate(Map<String, dynamic> json) {
    final errors = <String>[];
    if ((json['word'] as String? ?? '').trim().isEmpty) {
      errors.add('missing or empty "word"');
    }
    final persian = json['translation'] as String? ?? json['persian_translation'] as String? ?? '';
    if (persian.trim().isEmpty) {
      errors.add('missing or empty "translation"');
    }
    if ((json['english_translation'] as String? ?? '').trim().isEmpty) {
      errors.add('missing or empty "english_translation"');
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
      translation: json['translation'] as String? ??
          json['persian_translation'] as String? ??
          '',
      englishTranslation: json['english_translation'] as String? ?? '',
      persianDefinition: json['persian_definition'] as String? ?? '',
      englishDefinition: json['english_definition'] as String? ?? '',
      persianExample: json['persian_example'] as String? ??
          json['example_translation'] as String? ??
          '',
      englishExample: json['english_example'] as String? ?? '',
      concept: json['concept'] as String?,
      partOfSpeech: json['part_of_speech'] as String,
      level: json['level'] as String,
      example: json['example'] as String? ?? '',
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
        'concept': effectiveConcept,
        'word': word,
        'language': language,
        'part_of_speech': partOfSpeech,
        'level': level,
        'translation': translation,
        'english_translation': englishTranslation,
        'persian_definition': persianDefinition,
        'english_definition': englishDefinition,
        'example': example,
        'persian_example': persianExample,
        'english_example': englishExample,
        'lemma': lemma,
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
