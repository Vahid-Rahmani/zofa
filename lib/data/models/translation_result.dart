import 'translation_language.dart';

/// The outcome of a single dynamic translation lookup.
///
/// A lookup translates a [word] from a [source] language into a [target]
/// language. Beyond the plain gloss ([translation]) it may carry richer,
/// best-effort metadata fetched from the provider:
///
/// * [partOfSpeech] — e.g. `noun`, `verb`, `adjective`.
/// * [gender] — grammatical gender of nouns (e.g. `der`/`die`/`das` for
///   German), when the provider can determine it.
/// * [definition] — a fuller meaning written in the target language.
/// * [example] / [exampleTranslation] — a contextual sentence and its gloss.
/// * [alternates] — other accepted translations.
///
/// [fromCache] marks results served from the local cache (a repeat search or
/// an offline fallback); the UI shows a small "cached" badge for those.
class TranslationResult {
  const TranslationResult({
    required this.word,
    required this.source,
    required this.target,
    required this.translation,
    this.alternates = const [],
    this.partOfSpeech,
    this.gender,
    this.definition,
    this.example,
    this.exampleTranslation,
    this.fromCache = false,
    this.cachedAt,
  });

  /// The queried word in the source language.
  final String word;

  /// ISO 639-1 code of the source language, e.g. `en`, `de`.
  final String source;

  /// ISO 639-1 code of the target language, e.g. `fa`, `hi`, `es`.
  final String target;

  /// The primary gloss of [word] in [target].
  final String translation;

  /// Additional accepted translations (shortest/first is the primary).
  final List<String> alternates;

  /// Part of speech tag when the provider returns one.
  final String? partOfSpeech;

  /// Grammatical gender (`der`/`die`/`das`, `el`/`la`, ...) when known.
  final String? gender;

  /// A fuller meaning written in the target language, when available.
  final String? definition;

  /// A contextual example sentence in the source language.
  final String? example;

  /// Translation of [example] into [target].
  final String? exampleTranslation;

  /// True when this result came from the local cache rather than the network.
  final bool fromCache;

  /// When the result was cached, if known.
  final DateTime? cachedAt;

  /// The target language object, for RTL-aware rendering.
  TranslationLanguage? get targetLanguage => TranslationLanguage.byCode(target);

  /// The source language object.
  TranslationLanguage? get sourceLanguage => TranslationLanguage.byCode(source);

  /// Whether the target script is right-to-left.
  bool get isRtl => targetLanguage?.isRtl ?? false;

  /// True when the lookup returned nothing usable.
  bool get isEmpty => word.trim().isEmpty || translation.trim().isEmpty;

  /// The gloss line: translation plus the part-of-speech/gender tag, e.g.
  /// `سیب · noun` or `das Haus · noun`.
  String? get glossLine {
    final meta = <String>[
      if (gender != null && gender!.isNotEmpty) gender!,
      if (partOfSpeech != null && partOfSpeech!.isNotEmpty) partOfSpeech!,
    ];
    return meta.isEmpty ? null : meta.join(' · ');
  }

  TranslationResult copyWith({
    bool? fromCache,
    DateTime? cachedAt,
    String? translation,
    List<String>? alternates,
    String? partOfSpeech,
    String? gender,
    String? definition,
    String? example,
    String? exampleTranslation,
  }) {
    return TranslationResult(
      word: word,
      source: source,
      target: target,
      translation: translation ?? this.translation,
      alternates: alternates ?? this.alternates,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      gender: gender ?? this.gender,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      exampleTranslation: exampleTranslation ?? this.exampleTranslation,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation (used by the persistent cache)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'word': word,
        'source': source,
        'target': target,
        'translation': translation,
        'alternates': alternates,
        'part_of_speech': partOfSpeech,
        'gender': gender,
        'definition': definition,
        'example': example,
        'example_translation': exampleTranslation,
        'from_cache': fromCache,
        'cached_at': cachedAt?.toIso8601String(),
      };

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    final cachedAtRaw = json['cached_at'] as String?;
    return TranslationResult(
      word: json['word'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      translation: json['translation'] as String,
      alternates: [
        for (final e in (json['alternates'] as List<dynamic>? ?? const []))
          e as String,
      ],
      partOfSpeech: json['part_of_speech'] as String?,
      gender: json['gender'] as String?,
      definition: json['definition'] as String?,
      example: json['example'] as String?,
      exampleTranslation: json['example_translation'] as String?,
      fromCache: json['from_cache'] as bool? ?? false,
      cachedAt: cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw),
    );
  }
}
