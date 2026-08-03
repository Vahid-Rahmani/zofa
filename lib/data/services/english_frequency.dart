import 'dart:convert';

import 'package:flutter/foundation.dart'
    show SynchronousFuture, compute, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

/// A single CEFR level band over the frequency-ranked English word list.
class CefrLevelBand {
  const CefrLevelBand({
    required this.level,
    required this.firstRank,
    required this.lastRank,
  });

  /// The CEFR label (`A1`, `A2`, `B1`, ...).
  final String level;

  /// First 1-based frequency rank included in this band (inclusive).
  final int firstRank;

  /// Last 1-based frequency rank included in this band (inclusive).
  final int lastRank;

  /// Number of 1-based frequency ranks in the band.
  int get size => lastRank - firstRank + 1;

  /// Whether [rank] (1-based) falls inside this band.
  bool containsRank(int rank) => rank >= firstRank && rank <= lastRank;
}

/// CEFR bands for the 50,000-word English vocabulary list, ordered from the
/// most frequent (A1) to the least frequent (C2).
///
/// The bands approximate the common guidance that around the first 5,000
/// frequent words cover everyday English (A1–B1), with each higher level
/// extending into ever longer frequency tails.
const List<CefrLevelBand> kEnglishCefrBands = [
  CefrLevelBand(level: 'A1', firstRank: 1, lastRank: 1000),
  CefrLevelBand(level: 'A2', firstRank: 1001, lastRank: 2500),
  CefrLevelBand(level: 'B1', firstRank: 2501, lastRank: 5000),
  CefrLevelBand(level: 'B2', firstRank: 5001, lastRank: 10000),
  CefrLevelBand(level: 'C1', firstRank: 10001, lastRank: 25000),
  CefrLevelBand(level: 'C2', firstRank: 25001, lastRank: 50000),
];

/// The bundled 50,000 most-frequent English words (word + frequency rank).
///
/// The list ships as a plain JSON array of words ordered by corpus frequency
/// (rank 1 = most frequent). It powers the level-by-level Vocabulary tab:
/// every word is assigned a CEFR level ([levelForRank], [levelForWord]) from
/// [kEnglishCefrBands], and its translation, definition and example are
/// produced live by the dynamic [TranslationService] bridge on demand. The
/// list also serves instant, offline autocomplete in the Dictionary tab and
/// the "Word of the day" widget, exactly like the German 50k list.
///
/// The raw list is `hermitdave/FrequencyWords` (`en_full.txt`), licensed
/// CC BY-SA-4.0; see the project README attribution.
class EnglishFrequencyList {
  EnglishFrequencyList._(this._words);

  static const String assetPath = 'assets/dictionary/english_top_50k.json';

  final List<String> _words;

  static Future<EnglishFrequencyList>? _cache;

  /// Memoised async loader. Parsing runs in a background isolate so the 50k
  /// entries never block the UI thread.
  static Future<EnglishFrequencyList> get service => _cache ??= _load();

  static Future<EnglishFrequencyList> _load() {
    final override = _assetOverrides[assetPath];
    if (override != null) {
      return SynchronousFuture<EnglishFrequencyList>(
        EnglishFrequencyList._(_parse(override)),
      );
    }
    return _loadFromBundle();
  }

  static Future<EnglishFrequencyList> _loadFromBundle() async {
    final raw = await rootBundle.loadString(assetPath);
    return compute(_parseTopLevel, raw);
  }

  static EnglishFrequencyList _parseTopLevel(String raw) =>
      EnglishFrequencyList._(_parse(raw));

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

  /// The CEFR level for a 1-based frequency [rank], or `null` when out of
  /// range (beyond the bundled list).
  String? levelForRank(int rank) {
    for (final band in kEnglishCefrBands) {
      if (band.containsRank(rank)) return band.level;
    }
    return null;
  }

  /// The CEFR level of [word] (case-insensitive), or `null` when the word is
  /// not in the list.
  String? levelForWord(String word) {
    final rank = rankOf(word);
    return rank == null ? null : levelForRank(rank);
  }

  /// Words in the band for CEFR [level], in frequency order.
  List<String> wordsForLevel(String level) {
    final band = kEnglishCefrBands.firstWhere(
      (b) => b.level == level,
      orElse: () => const CefrLevelBand(level: '', firstRank: 0, lastRank: 0),
    );
    if (band.firstRank == 0) return const [];
    final first = (band.firstRank - 1).clamp(0, _words.length);
    final last = band.lastRank.clamp(0, _words.length);
    return List.unmodifiable(_words.sublist(first, last));
  }

  /// Number of words in the band for CEFR [level] (0 when unknown).
  int countForLevel(String level) {
    final band = kEnglishCefrBands.firstWhere(
      (b) => b.level == level,
      orElse: () => const CefrLevelBand(level: '', firstRank: 0, lastRank: 0),
    );
    if (band.firstRank == 0) return 0;
    final first = (band.firstRank - 1).clamp(0, _words.length);
    final last = band.lastRank.clamp(0, _words.length);
    return last - first;
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
