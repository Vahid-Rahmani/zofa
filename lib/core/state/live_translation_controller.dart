import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../../data/services/normalize.dart' as normalize;
import '../utils/clean_text.dart';

/// Base class for live, cached, on-device translation of English text into a
/// chosen target language.
///
/// The first time a language is used the strings are fetched from the public
/// Google Translate endpoint and then cached on-device (Hive), so later
/// launches are instant and work offline. When Hive is unavailable (tests,
/// web) the controller stays memory-only.
///
/// Subclasses pin the meaning of the target language:
///   * [UiTranslationController] — the app UI, into the native language.
///   * [ContentTranslationController] — learning content (words, book
///     sentences, grammar), into the native language.
///
/// Strings are fetched lazily (only the text actually on screen) and the
/// controller notifies listeners when a batch arrives so the tree rebuilds
/// with the localized text.
abstract class LiveTranslationController extends ChangeNotifier {
  LiveTranslationController({
    String? code,
    required String boxName,
    Future<String?> Function(String text, String target)? translator,
  })  : _code = code ?? 'en',
        _boxName = boxName,
        _translator = translator ?? _googleTranslate;

  /// The target language (ISO 639-1). English needs no translation.
  String _code;

  /// Hive box holding this controller's cache (separate per subclass).
  final String _boxName;

  /// Pluggable translator for tests: `(english, targetCode) -> translation`.
  final Future<String?> Function(String text, String target) _translator;

  final Map<String, String> _memory = {};
  final Set<String> _inFlight = {};
  Box<dynamic>? _box;

  String get code => _code;

  /// Opens the persistent translation box. Safe to call at boot; in test and
  /// web environments without Hive the controller stays memory-only.
  Future<void> bootstrap() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox(_boxName);
      }
      _box = Hive.box(_boxName);
    } catch (_) {
      _box = null;
    }
  }

  /// Switches the target language and drops the hot cache. Already-translated
  /// strings for the new code are re-read from the persistent box.
  void setCode(String code) {
    if (code == _code) return;
    _code = code;
    _memory.clear();
    notifyListeners();
  }

  /// Best available translation of [text] into the target language, or [text]
  /// itself while the live translation is pending (and for English).
  String tr(String text) {
    if (_code == 'en') return text;
    final key = _key(text);
    final cached = _memory[key];
    if (cached != null) return cached;
    final persisted = _box?.get(key);
    if (persisted is String && persisted.isNotEmpty) {
      _memory[key] = persisted;
      return persisted;
    }
    _ensure(text, key);
    return text;
  }

  /// Immediately translates [text] (bypassing nothing — still cached), used
  /// by tests and non-widget code that needs the result before building.
  Future<String> translate(String text) async {
    if (_code == 'en') return text;
    final key = _key(text);
    final cached = _memory[key];
    if (cached != null) return cached;
    final persisted = _box?.get(key);
    if (persisted is String && persisted.isNotEmpty) {
      _memory[key] = persisted;
      return persisted;
    }
    final translated = await _translator(text, _code);
    if (translated != null && translated.isNotEmpty) {
      _memory[key] = translated;
      try {
        await _box?.put(key, translated);
      } catch (_) {}
    }
    notifyListeners();
    return translated ?? text;
  }

  /// Pre-translates [strings] in the background so a screen shows localized
  /// text without the English flash.
  void prewarm(Iterable<String> strings) {
    for (final text in strings) {
      tr(text);
    }
  }

  String _key(String text) =>
      '$_code|${normalize.slug(normalize.normalizeText(text))}';

  void _ensure(String text, String key) {
    if (_inFlight.contains(key)) return;
    _inFlight.add(key);
    _translator(text, _code).then((translated) {
      _inFlight.remove(key);
      if (translated == null || translated.isEmpty) return;
      _memory[key] = translated;
      try {
        _box?.put(key, translated);
      } catch (_) {}
      notifyListeners();
    }).catchError((_) {
      _inFlight.remove(key);
    });
  }

  /// Live lookup against the public Google Translate `gtx` endpoint (the same
  /// provider used for word translations elsewhere in the app).
  static Future<String?> _googleTranslate(String text, String target) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx'
        '&sl=en'
        '&tl=${Uri.encodeQueryComponent(target)}'
        '&dt=t'
        '&dj=1'
        '&q=${Uri.encodeQueryComponent(text)}',
      );
      final response =
          await client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        return null;
      }
      if (decoded is! Map<String, dynamic>) return null;
      final sentences = decoded['sentences'] as List<dynamic>? ?? const [];
      final translated = cleanText(
        sentences
            .map((s) => (s as Map<String, dynamic>)['trans'] as String? ?? '')
            .join(),
      );
      return translated.isEmpty ? null : translated;
    } on Exception {
      return null;
    } finally {
      client.close();
    }
  }
}
