import 'dart:convert';

import 'package:flutter/foundation.dart' show SynchronousFuture, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../models/dictionary_entry.dart';

/// In-memory index over a set of [DictionaryEntry]s for one source language.
///
/// A service is immutable once created: it only caches the lookup index
/// lazily. It powers the Dictionary tab, the word-tap lookups in the reader
/// and the lesson builder. The word data itself lives in JSON assets (see
/// [loadAsset]) so thousands of entries load quickly without cluttering the
/// Dart source tree.
class DictionaryService {
  DictionaryService(this._entries);

  /// Parses a JSON array of entry objects produced by `DictionaryEntry.toJson`.
  factory DictionaryService.fromJsonString(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    final entries = [
      for (final item in decoded) DictionaryEntry.fromJson(item as Map<String, dynamic>),
    ];
    return DictionaryService(entries);
  }

  /// Overrides used by tests to serve assets synchronously, so widget tests
  /// never depend on real file I/O (which cannot complete under the fake
  /// async test clock). Not used in production.
  static final Map<String, String> _assetOverrides = {};

  /// Seeds the bundled JSON contents for [path] for the current test.
  @visibleForTesting
  static void seedAsset(String path, String jsonContents) {
    _assetOverrides[path] = jsonContents;
  }

  /// Asynchronously loads and parses a bundled JSON dictionary asset. When a
  /// test seeded [path] via [seedAsset] the value completes synchronously.
  static Future<DictionaryService> loadAsset(String path) {
    final override = _assetOverrides[path];
    if (override != null) {
      return SynchronousFuture<DictionaryService>(
        DictionaryService.fromJsonString(override),
      );
    }
    return _loadFromBundle(path);
  }

  static Future<DictionaryService> _loadFromBundle(String path) async {
    final raw = await rootBundle.loadString(path);
    return DictionaryService.fromJsonString(raw);
  }

  final List<DictionaryEntry> _entries;

  late final Map<String, DictionaryEntry> _byWord = {
    for (final entry in _entries) _normalize(entry.word): entry,
  };

  /// Every entry in its original (curated) order.
  List<DictionaryEntry> get entries => List.unmodifiable(_entries);

  /// Every entry, sorted alphabetically.
  List<DictionaryEntry> get all =>
      List.unmodifiable([..._entries]..sort((a, b) => a.word.compareTo(b.word)));

  /// Number of headwords in the dictionary.
  int get wordCount => _entries.length;

  /// Number of entries that teach an example sentence.
  int get exampleCount =>
      _entries.where((e) => e.example.isNotEmpty).length;

  /// Looks up [word] case-insensitively, ignoring punctuation and articles.
  DictionaryEntry? lookup(String word) {
    final normalized = _normalize(word);
    if (normalized.isEmpty) return null;
    return _byWord[normalized];
  }

  /// Convenience: the translation of [word], when known.
  String? translation(String word) => lookup(word)?.translation;

  /// Filters entries by CEFR [level] (`A1`, `A2`, `B1`).
  List<DictionaryEntry> byLevel(String level) =>
      List.unmodifiable(_entries.where((e) => e.level == level));

  /// Fuzzy search across headwords, translations and examples. Works for
  /// Latin and Persian queries alike.
  List<DictionaryEntry> search(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return all;
    return List.unmodifiable(
      _entries.where((e) =>
          _normalize(e.word).contains(q) ||
          e.translation.contains(q) ||
          _normalize(e.example).contains(q)),
    );
  }

  /// Normalises [raw] for lookup and search: lowercases, collapses whitespace
  /// and strips punctuation while keeping all letters (Latin and Persian) and
  /// digits, so English, German and Persian queries all work.
  static String _normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r"[\u2018\u2019']"), '')
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r"\s{2,}"), ' ');
  }
}
