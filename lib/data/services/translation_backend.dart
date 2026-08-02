import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/env_config.dart';
import '../../core/utils/clean_text.dart';
import '../models/translation_result.dart';

/// A single lookup request against a translation provider.
class TranslationRequest {
  const TranslationRequest({
    required this.word,
    required this.source,
    required this.target,
  });

  /// The word or short phrase to look up, in the source language.
  final String word;

  /// ISO 639-1 source language code.
  final String source;

  /// ISO 639-1 target language code.
  final String target;
}

/// A pluggable translation/lookup provider.
///
/// The dynamic bridge supports any language pair; concrete providers decide
/// what metadata (part of speech, gender, definition, example) they can
/// enrich a result with. Implementations should return `null` — never throw —
/// when they cannot answer, so the [TranslationService] can fall back to its
/// local cache.
abstract class TranslationBackend {
  /// Looks up [request] and returns the best available result, or `null` when
  /// the provider has no data for the word (offline, unknown word, ...).
  Future<TranslationResult?> lookup(TranslationRequest request);
}

/// Returns the backend to use by default: a custom bridge endpoint when one is
/// configured (e.g. a self-hosted LLM proxy), otherwise the free online
/// Google Translate + Wiktionary provider.
TranslationBackend buildDefaultTranslationBackend() =>
    EnvConfig.hasTranslationEndpoint
        ? ConfiguredEndpointBackend()
        : OnlineTranslationBackend();

/// Real-time translation bridge backed by the public Google Translate lookup
/// endpoint (no API key) enriched with Wiktionary for definitions, German
/// grammatical gender and contextual example sentences.
///
/// Everything beyond the plain gloss is best-effort: if Wiktionary is slow or
/// unavailable the result still carries the gloss from the translation call.
class OnlineTranslationBackend implements TranslationBackend {
  OnlineTranslationBackend({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 6),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration requestTimeout;

  static const String _googleUrl = 'https://translate.googleapis.com/translate_a/single';

  @override
  Future<TranslationResult?> lookup(TranslationRequest request) async {
    try {
      final gloss = await _googleLookup(request);
      if (gloss == null) return null;
      return await _enrich(request, gloss);
    } on Exception {
      return null;
    }
  }

  /// Core gloss lookup via the Google Translate `gtx` endpoint.
  ///
  /// `dt=t` returns the plain sentence translation, `dt=bd` the dictionary
  /// breakdown (part of speech + alternate terms) used for [pos] and
  /// [alternates].
  Future<TranslationResult?> _googleLookup(TranslationRequest request) async {
    final query = [
      'client=gtx',
      'sl=${Uri.encodeQueryComponent(request.source)}',
      'tl=${Uri.encodeQueryComponent(request.target)}',
      'dt=t',
      'dt=bd',
      'dj=1',
      'q=${Uri.encodeQueryComponent(request.word)}',
    ].join('&');
    final response = await _client
        .get(Uri.parse('$_googleUrl?$query'))
        .timeout(requestTimeout);
    if (response.statusCode != 200) return null;
    return parseGoogleResponse(
      response.body,
      word: request.word,
      source: request.source,
      target: request.target,
    );
  }

  /// Best-effort enrichment with Wiktionary metadata. Never throws: any
  /// failure leaves the base gloss untouched.
  Future<TranslationResult> _enrich(
    TranslationRequest request,
    TranslationResult base,
  ) async {
    try {
      final genderFuture = _fetchGender(request);
      final definitionFuture = _fetchDefinition(request);
      final gender = await genderFuture;
      final defs = await definitionFuture;

      String? exampleTranslation;
      if (defs.example != null && request.source != request.target) {
        exampleTranslation =
            await _googleGloss(defs.example!, request.source, request.target);
      }
      return base.copyWith(
        gender: gender,
        definition: defs.definition,
        example: defs.example,
        exampleTranslation: exampleTranslation,
      );
    } on Exception {
      return base;
    }
  }

  Future<String?> _fetchGender(TranslationRequest request) async {
    try {
      final uri = Uri.parse(
        'https://${request.source}.wiktionary.org/api/rest_v1/page/summary/'
        '${Uri.encodeComponent(request.word)}',
      );
      final response =
          await _client.get(uri).timeout(requestTimeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return genderFromSummary(json);
    } on Exception {
      return null;
    }
  }

  Future<({String? definition, String? example})> _fetchDefinition(
    TranslationRequest request,
  ) async {
    try {
      final uri = Uri.parse(
        'https://${request.source}.wiktionary.org/api/rest_v1/page/definition/'
        '${Uri.encodeComponent(request.word)}',
      );
      final response =
          await _client.get(uri).timeout(requestTimeout);
      if (response.statusCode != 200) return (definition: null, example: null);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return firstDefinition(json, request.source);
    } on Exception {
      return (definition: null, example: null);
    }
  }

  Future<String?> _googleGloss(
    String text,
    String source,
    String target,
  ) async {
    final request = TranslationRequest(word: text, source: source, target: target);
    final result = await _googleLookup(request);
    return result?.translation;
  }

  // -------------------------------------------------------------------------
  // Pure response parsers (exposed for unit tests)
  // -------------------------------------------------------------------------

  /// Parses a `dj=1` Google Translate response into a [TranslationResult].
  static TranslationResult? parseGoogleResponse(
    String body, {
    required String word,
    required String source,
    required String target,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final sentences = decoded['sentences'] as List<dynamic>? ?? const [];
    final translation = cleanText(
      sentences
          .map((s) => (s as Map<String, dynamic>)['trans'] as String? ?? '')
          .join(),
    );
    if (translation.isEmpty) return null;

    final dict = decoded['dict'] as List<dynamic>? ?? const [];
    String? partOfSpeech;
    final terms = <String>[];
    for (final raw in dict) {
      final entry = raw as Map<String, dynamic>;
      final pos = entry['pos'] as String?;
      if (pos != null && pos.trim().isNotEmpty) {
        partOfSpeech ??= cleanText(pos);
      }
      for (final term in entry['terms'] as List<dynamic>? ?? const []) {
        if (term is! String) continue;
        final cleaned = cleanText(term);
        if (cleaned.isNotEmpty && cleaned != translation) {
          terms.add(cleaned);
        }
      }
    }

    return TranslationResult(
      word: word,
      source: source,
      target: target,
      translation: translation,
      partOfSpeech: partOfSpeech,
      alternates: terms.toSet().take(8).toList(),
    );
  }

  /// Extracts grammatical gender from a Wiktionary page-summary response. The
  /// summary of a German noun typically begins with its article, e.g.
  /// `"Das Haus (Mehrzahl: die Häuser) ..."` -> `das`.
  static String? genderFromSummary(Map<String, dynamic> json) {
    final extract = json['extract'] as String?;
    if (extract == null) return null;
    final match = RegExp(
      r'^\s*(der|die|das)\b',
      caseSensitive: false,
    ).firstMatch(cleanText(extract));
    return match?.group(1)?.toLowerCase();
  }

  /// Pulls the first useful definition (and its first example sentence) from a
  /// Wiktionary `/definition/` response, which is keyed by language code.
  static ({String? definition, String? example}) firstDefinition(
    Map<String, dynamic> json,
    String code,
  ) {
    final blocks = json[code] as List<dynamic>? ?? const [];
    for (final raw in blocks) {
      final block = raw as Map<String, dynamic>;
      for (final rawDef in block['definitions'] as List<dynamic>? ?? const []) {
        final def = rawDef as Map<String, dynamic>;
        final definition = cleanText(def['definition'] as String? ?? '');
        if (definition.isEmpty) continue;
        String? example;
        for (final rawExample
            in def['parsedExamples'] as List<dynamic>? ?? const []) {
          final text = cleanText(
            (rawExample as Map<String, dynamic>)['example'] as String? ?? '',
          );
          if (text.isNotEmpty) {
            example = text;
            break;
          }
        }
        return (definition: definition, example: example);
      }
    }
    return (definition: null, example: null);
  }
}

/// Bridge to a custom translation endpoint (e.g. a self-hosted LLM proxy).
///
/// Configured via `ZOVA_TRANSLATION_ENDPOINT`; the app POSTs
/// `{"word": ..., "source": ..., "target": ...}` and expects a JSON object
/// with a `translation` field and optional `part_of_speech`, `gender`,
/// `definition`, `example`, `example_translation` and `alternates` fields.
class ConfiguredEndpointBackend implements TranslationBackend {
  ConfiguredEndpointBackend({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<TranslationResult?> lookup(TranslationRequest request) async {
    try {
      final response = await _client
          .post(
            Uri.parse(EnvConfig.translationEndpoint),
            headers: {
              'content-type': 'application/json',
              if (EnvConfig.translationApiKey.isNotEmpty)
                'authorization': 'Bearer ${EnvConfig.translationApiKey}',
            },
            body: jsonEncode({
              'word': request.word,
              'source': request.source,
              'target': request.target,
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final translation = cleanText(json['translation'] as String? ?? '');
      if (translation.isEmpty) return null;
      return TranslationResult(
        word: request.word,
        source: request.source,
        target: request.target,
        translation: translation,
        partOfSpeech: _cleanNullable(json['part_of_speech'] as String?),
        gender: _cleanNullable(json['gender'] as String?),
        definition: _cleanNullable(json['definition'] as String?),
        example: _cleanNullable(json['example'] as String?),
        exampleTranslation:
            _cleanNullable(json['example_translation'] as String?),
        alternates: [
          for (final e in (json['alternates'] as List<dynamic>? ?? const []))
            if (e is String && cleanText(e).isNotEmpty) cleanText(e),
        ],
      );
    } on Exception {
      return null;
    }
  }

  static String? _cleanNullable(String? value) {
    if (value == null) return null;
    final cleaned = cleanText(value);
    return cleaned.isEmpty ? null : cleaned;
  }
}
