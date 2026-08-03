import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/config/env_config.dart';
import '../../core/utils/clean_text.dart';
import '../models/ai_grammar_explanation.dart';
import '../models/ai_word_details.dart';
import 'ai_backend.dart';
import 'ai_cache.dart';
import 'normalize.dart' as normalize;

/// A free-form answer from the AI tutor.
class AiTutorReply {
  const AiTutorReply({required this.answer, this.fromCache = false});

  /// The tutor's answer text (in the learner's native language).
  final String answer;

  /// True when served from the local cache rather than the model.
  final bool fromCache;

  bool get isEmpty => answer.trim().isEmpty;
}

/// The AI tutor: on-demand translations, examples, phonetics and grammar
/// explanations powered by a hosted model (Google Gemini by default, any
/// OpenAI-compatible endpoint via config).
///
/// Every request is a strict-JSON prompt. Responses are cached locally through
/// the same LRU/Hive pattern as the translation bridge, so:
///
/// * repeating a word or question is instant and works offline;
/// * rate-limited providers are queried once per unique request;
/// * any backend failure (network, quota, malformed reply) degrades to `null`
///   and callers fall back to their bundled/static data.
///
/// Use [instance] (set once at startup in `main.dart`, and swapped for a fake
/// backend in tests). When no API key is configured the service is disabled
/// and every call returns `null` without touching the network.
class AiTutorService {
  AiTutorService({
    required AiBackend backend,
    required AiCache cache,
    bool? enabled,
  })  : _backend = backend,
        _cache = cache,
        _enabled = enabled ?? EnvConfig.hasAi;

  /// The shared app-wide instance. Reassign in tests via a fake backend and
  /// an in-memory cache.
  static AiTutorService instance = AiTutorService(
    backend: buildDefaultAiBackend(),
    cache: MemoryAiCache(),
  );

  final AiBackend _backend;
  final AiCache _cache;
  final bool _enabled;

  /// Whether an API key is configured and the tutor can answer.
  bool get isConfigured => _enabled;

  /// Runs a backend request, swallowing any transport/network error so the
  /// service degrades to `null` (and callers fall back to static data).
  Future<String?> _callBackend(AiChatRequest request) async {
    try {
      return await _backend.completeText(request);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Cache keys
  // ---------------------------------------------------------------------------

  static String _slug(String text) =>
      normalize.slug(normalize.normalizeText(text));

  /// Canonical cache key for a word-details lookup.
  static String wordCacheKey({
    required String word,
    required String source,
    required String target,
  }) =>
      'ai|word|$source|$target|${_slug(word)}';

  /// Canonical cache key for a grammar-explanation lookup.
  static String grammarCacheKey({
    required String topic,
    required String source,
    required String target,
  }) =>
      'ai|grammar|$source|$target|${_slug(topic)}';

  /// Canonical cache key for a free-form tutor question.
  static String tutorCacheKey(String question) => 'ai|tutor|${_slug(question)}';

  // ---------------------------------------------------------------------------
  // Word details
  // ---------------------------------------------------------------------------

  /// Generates rich details for [word] from [source] into [target]: the gloss,
  /// phonetic guide, part of speech, grammatical gender (e.g. `der`/`die`/`das`)
  /// and contextual example sentences with translations.
  ///
  /// Returns `null` when the AI is unavailable or could not produce a usable
  /// answer — the caller keeps its static/offline fallback.
  Future<AiWordDetails?> wordDetails({
    required String word,
    required String source,
    required String target,
    bool forceRefresh = false,
  }) async {
    if (!_enabled) return null;
    final query = word.trim();
    if (query.isEmpty) return null;
    final key = wordCacheKey(word: query, source: source, target: target);

    if (!forceRefresh) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final parsed = AiWordDetails.fromJson(_decodeMap(cached));
        if (parsed.hasAnything) {
          return parsed.copyWith(fromCache: true);
        }
      }
    }

    final details = await _callBackend(
      AiChatRequest(
        system: _wordDetailsSystem(source, target),
        user: _wordDetailsUser(query, source, target),
        maxTokens: 1000,
      ),
    );
    if (details == null) return null;
    final parsed =
        parseWordDetails(details, word: query, source: source, target: target);
    if (parsed == null || parsed.isEmpty || !parsed.hasAnything) return null;

    await _cache.put(key, jsonEncode(parsed.toJson()));
    return parsed.copyWith(fromCache: false, cachedAt: DateTime.now());
  }

  static String _wordDetailsSystem(String source, String target) =>
      'You are a language tutor inside the zova learning app. The learner is '
      'learning $source and reads explanations in $target. Return ONLY a valid '
      'JSON object — no markdown, no commentary, no code fences. Use exactly '
      'the keys requested. Definitions, example translations and glosses must '
      'be written in $target; example sentences themselves stay in $source. '
      'Do not invent facts: if a field is unknown or does not apply, set it to '
      'null (or an empty list).';

  static String _wordDetailsUser(String word, String source, String target) =>
      'Look up the word "$word" ($source). Respond with this strict JSON '
      'schema:\n'
      '{\n'
      '  "translation": "the best $target gloss",\n'
      '  "phonetic": "IPA pronunciation guide, or a pronunciation hint in '
      '$target script",\n'
      '  "part_of_speech": "noun | verb | adjective | adverb | ... or null",\n'
      '  "gender": "the noun gender article if $source genders nouns (e.g. '
      'der/die/das for German), otherwise null",\n'
      '  "definition": "a short $target-language definition",\n'
      '  "examples": [{"sentence": "$source sentence", "translation": '
      '"$target translation"}, ...] — up to 3,\n'
      '  "alternates": ["other accepted $target translations", ...] — up to 4\n'
      '}\n'
      'If $source genders nouns (German, Spanish, French, ...), always fill '
      'the gender field with the article and noun, e.g. "das Haus".';

  // ---------------------------------------------------------------------------
  // Grammar explanations
  // ---------------------------------------------------------------------------

  /// Explains a grammar rule or answers a grammar question in [target].
  ///
  /// [topicOrQuestion] is the learner's phrasing (e.g. "plurals" or "why is it
  /// 'the' not 'a'?"); the answer is a structured [AiGrammarExplanation] with a
  /// summary, a full explanation, glossed examples and a tip. Returns `null`
  /// when the AI is unavailable.
  Future<AiGrammarExplanation?> explainGrammar({
    required String topicOrQuestion,
    required String source,
    required String target,
    bool forceRefresh = false,
  }) async {
    if (!_enabled) return null;
    final topic = topicOrQuestion.trim();
    if (topic.isEmpty) return null;
    final key = grammarCacheKey(topic: topic, source: source, target: target);

    if (!forceRefresh) {
      final cached = await _cache.get(key);
      if (cached != null) {
        final parsed = AiGrammarExplanation.fromJson(_decodeMap(cached));
        if (parsed.hasAnything) {
          return parsed.copyWith(fromCache: true);
        }
      }
    }

    final answer = await _callBackend(
      AiChatRequest(
        system: _grammarSystem(source, target),
        user: topic,
        maxTokens: 1200,
      ),
    );
    if (answer == null) return null;
    final parsed = parseGrammarExplanation(answer, topic: topic);
    if (parsed == null || parsed.isEmpty || !parsed.hasAnything) return null;

    await _cache.put(key, jsonEncode(parsed.toJson()));
    return parsed.copyWith(fromCache: false, cachedAt: DateTime.now());
  }

  static String _grammarSystem(String source, String target) =>
      'You are a patient grammar tutor inside the zova learning app. The '
      'learner is learning $source and reads explanations in $target. Answer '
      'the learner\'s grammar question clearly and briefly (a beginner-friendly '
      'tone, plain words, no jargon without an explanation). Return ONLY a '
      'valid JSON object with exactly this schema:\n'
      '{\n'
      '  "summary": "one-sentence takeaway in $target",\n'
      '  "explanation": "the full explanation in $target",\n'
      '  "examples": [{"sentence": "$source example", "translation": '
      '"$target translation"}, ...] — 2 to 4,\n'
      '  "tip": "a short memory aid in $target, or null"\n'
      '}\n'
      'No markdown, no code fences.';

  // ---------------------------------------------------------------------------
  // Free-form tutor questions
  // ---------------------------------------------------------------------------

  /// Answers a free-form question from the learner, in their native language
  /// [target]. [sessionContext] may describe what they are currently studying
  /// (e.g. "Grammar", "Lesson: Greetings") so the answer can be contextual.
  ///
  /// Returns the raw answer text (not JSON), or `null` when unavailable.
  Future<AiTutorReply?> askTutor({
    required String question,
    required String source,
    required String target,
    String? sessionContext,
  }) async {
    if (!_enabled) return null;
    final text = question.trim();
    if (text.isEmpty) return null;
    final key = tutorCacheKey(text);

    final cached = await _cache.get(key);
    if (cached != null) {
      return AiTutorReply(answer: cached, fromCache: true);
    }

    final contextLine = sessionContext == null || sessionContext.trim().isEmpty
        ? ''
        : ' The learner is currently in "${sessionContext.trim()}".';
    final answer = await _callBackend(
      AiChatRequest(
        system: 'You are zova\'s AI language tutor. The learner is learning '
            '$source and their native language is $target. Answer in $target, '
            'concise and beginner-friendly, with one $source example when it '
            'helps.$contextLine',
        user: text,
        maxTokens: 700,
      ),
    );
    if (answer == null || answer.trim().isEmpty) return null;

    await _cache.put(key, answer.trim());
    return AiTutorReply(answer: answer.trim(), fromCache: false);
  }

  // ---------------------------------------------------------------------------
  // Response parsing (pure, exposed for unit tests)
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _decodeMap(String json) {
    final decoded = jsonDecode(json);
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Pulls a JSON object out of a model reply, tolerating markdown fences and
  /// surrounding prose.
  static Map<String, dynamic>? extractJson(String body) {
    var text = body.trim();
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Parses a word-details JSON reply into an [AiWordDetails]. Returns `null`
  /// when no usable gloss could be extracted.
  static AiWordDetails? parseWordDetails(
    String body, {
    required String word,
    required String source,
    required String target,
  }) {
    final json = extractJson(body);
    if (json == null) return null;
    final translation = _clean(json['translation'] as String?);
    if (translation == null) return null;

    return AiWordDetails(
      word: word,
      source: source,
      target: target,
      translation: translation,
      phonetic: _clean(json['phonetic'] as String?),
      partOfSpeech: _clean(json['part_of_speech'] as String?),
      gender: _clean(json['gender'] as String?),
      definition: _clean(json['definition'] as String?),
      examples: [
        for (final raw in (json['examples'] as List<dynamic>? ?? const []))
          if (raw is Map) _parseExample(Map<String, dynamic>.from(raw)),
      ].where((e) => !e.isEmpty).toList(),
      alternates: [
        for (final raw in (json['alternates'] as List<dynamic>? ?? const []))
          if (raw is String && _clean(raw) != null) _clean(raw)!,
      ],
    );
  }

  /// Parses a grammar-explanation JSON reply. Returns `null` when neither a
  /// summary nor a full explanation could be extracted.
  static AiGrammarExplanation? parseGrammarExplanation(
    String body, {
    required String topic,
  }) {
    final json = extractJson(body);
    if (json == null) return null;
    final summary = _clean(json['summary'] as String?);
    final explanation = _clean(json['explanation'] as String?);
    if (summary == null && explanation == null) return null;

    return AiGrammarExplanation(
      topic: topic,
      summary: summary,
      explanation: explanation,
      examples: [
        for (final raw in (json['examples'] as List<dynamic>? ?? const []))
          if (raw is Map) _parseExample(Map<String, dynamic>.from(raw)),
      ].where((e) => !e.isEmpty).toList(),
      tip: _clean(json['tip'] as String?),
    );
  }

  static AiExample _parseExample(Map<String, dynamic> json) => AiExample(
        sentence: _clean(json['sentence'] as String?) ?? '',
        translation: _clean(json['translation'] as String?) ?? '',
      );

  static String? _clean(String? value) {
    if (value == null) return null;
    final cleaned = cleanText(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  // ---------------------------------------------------------------------------
  // Test hooks
  // ---------------------------------------------------------------------------

  /// Swaps the shared instance (used by widget tests with a fake backend).
  @visibleForTesting
  static set instanceForTesting(AiTutorService service) => instance = service;
}
