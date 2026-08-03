import 'dart:convert';

import 'package:flutter/foundation.dart'
    show SynchronousFuture, compute, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

/// The bundled 50,000 most-frequent German words (word + rank).
///
/// The list ships as a plain JSON array of words ordered by corpus frequency
/// (rank 1 = most frequent). It powers instant, offline autocomplete in the
/// Dictionary tab, the "Word of the day" widget and the frequency rank shown
/// on word detail screens. Words here have no part-of-speech / CEFR / example
/// metadata — those come from the curated `german.json` pack or from the live
/// translation bridge on demand.
///
/// The raw list is `hermitdave/FrequencyWords` (`de_50k.txt`), licensed
/// CC BY-SA-4.0; see the project README attribution.
class GermanFrequencyList {
  GermanFrequencyList._(this._words);

  static const String assetPath = 'assets/dictionary/german_top_50k.json';

  final List<String> _words;

  static Future<GermanFrequencyList>? _cache;

  /// Memoised async loader. Parsing runs in a background isolate so the 50k
  /// entries never block the UI thread.
  static Future<GermanFrequencyList> get service => _cache ??= _load();

  static Future<GermanFrequencyList> _load() {
    final override = _assetOverrides[assetPath];
    if (override != null) {
      return SynchronousFuture<GermanFrequencyList>(
        GermanFrequencyList._(_parse(override)),
      );
    }
    return _loadFromBundle();
  }

  static Future<GermanFrequencyList> _loadFromBundle() async {
    final raw = await rootBundle.loadString(assetPath);
    return compute(_parseTopLevel, raw);
  }

  static GermanFrequencyList _parseTopLevel(String raw) =>
      GermanFrequencyList._(_parse(raw));

  static List<String> _parse(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>();
  }

  /// Test hook mirroring [DictionaryService.seedAsset]: widget tests serve the
  /// bundled list synchronously so they have no pending asset I/O under the
  /// fake async clock.
  static final Map<String, String> _assetOverrides = {};

  @visibleForTesting
  static void seedAsset(String path, String contents) {
    _assetOverrides[path] = contents;
  }

  @visibleForTesting
  static void reset() => _cache = null;

  /// Total number of words in the list (50,000 for the bundled asset).
  int get length => _words.length;

  /// The word at 1-based frequency [rank], or `null` when out of range.
  String? wordAtRank(int rank) {
    if (rank < 1 || rank > _words.length) return null;
    return _words[rank - 1];
  }

  /// 1-based frequency rank of [word] (case-insensitive), or `null` when the
  /// word is not in the list.
  int? rankOf(String word) {
    final target = word.toLowerCase();
    for (var i = 0; i < _words.length; i++) {
      if (_words[i] == target) return i + 1;
    }
    return null;
  }

  /// Up to [limit] words whose headword starts with [prefix]
  /// (case-insensitive, ordered by frequency). Used for instant autocomplete.
  List<String> suggestions(String prefix, {int limit = 8}) {
    final q = prefix.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final matches = <String>[];
    for (final word in _words) {
      if (word.startsWith(q)) {
        matches.add(word);
        if (matches.length >= limit) break;
      }
    }
    return matches;
  }

  /// Whether [word] is present (case-insensitive).
  bool contains(String word) => rankOf(word) != null;

  /// The deterministic "word of the day" for [date]: the same word for every
  /// learner on the same day, changing daily. Skips the top 250 function words
  /// so the featured word is always worth learning.
  String wordOfDay(DateTime date) {
    if (_words.isEmpty) return '';
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final start = _words.length <= 250 ? 0 : 250;
    return _words[start + (seed % (_words.length - start))];
  }
}
