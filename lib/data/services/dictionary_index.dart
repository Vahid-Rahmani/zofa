import 'dart:convert';

import '../models/dictionary_entry.dart';
import 'normalize.dart';

/// Persistent lookup index over a set of [DictionaryEntry]s.
///
/// Built once (by the import tool, or in memory from loaded entries) and
/// serialised to a compact JSON sidecar that ships next to the entries asset.
/// The index answers exact lookups, headword-prefix searches and
/// level / part-of-speech / tag filters in O(log n + k) without scanning every
/// entry, which keeps the app fast even with hundreds of thousands of words.
///
/// Positions in the index refer to positions in the entries list, so the
/// entries asset stays the single source of truth: the sidecar never carries
/// the entries themselves.
class DictionaryIndex {
  DictionaryIndex._({
    required this.sortedWords,
    required this.sortedPositions,
    required this.levels,
    required this.partsOfSpeech,
    required this.tags,
  });

  /// Builds an in-memory index over [entries] (used when no sidecar asset is
  /// available, e.g. for seeded test data).
  factory DictionaryIndex.build(List<DictionaryEntry> entries) {
    final sorted = <MapEntry<String, int>>[
      for (var i = 0; i < entries.length; i++)
        MapEntry(normalizeText(entries[i].word), i),
    ]..sort((a, b) => a.key.compareTo(b.key));

    final levels = <String, List<int>>{};
    final pos = <String, List<int>>{};
    final tags = <String, List<int>>{};

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      (levels[e.level] ??= <int>[]).add(i);
      (pos[normalizeText(e.partOfSpeech)] ??= <int>[]).add(i);
      for (final t in e.topics) {
        (tags[normalizeText(t)] ??= <int>[]).add(i);
      }
      for (final t in e.tags) {
        (tags[normalizeText(t)] ??= <int>[]).add(i);
      }
    }

    return DictionaryIndex._(
      sortedWords: [for (final m in sorted) m.key],
      sortedPositions: [for (final m in sorted) m.value],
      levels: levels,
      partsOfSpeech: pos,
      tags: tags,
    );
  }

  /// Reads an index previously written by [toJsonString].
  factory DictionaryIndex.fromJsonString(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return DictionaryIndex._(
      sortedWords: [
        for (final w in m['sorted'] as List<dynamic>) w as String,
      ],
      sortedPositions: [
        for (final p in m['sortedPos'] as List<dynamic>) (p as num).toInt(),
      ],
      levels: _decodeMap(m['levels']),
      partsOfSpeech: _decodeMap(m['pos']),
      tags: _decodeMap(m['tags']),
    );
  }

  /// Sorted normalised headwords, with [sortedPositions] holding each word's
  /// position in the entries list. Serves both exact lookups and prefix
  /// searches via binary search.
  final List<String> sortedWords;
  final List<int> sortedPositions;

  /// Positions of entries carrying each CEFR level (`A1` ... `C2`).
  final Map<String, List<int>> levels;

  /// Positions of entries carrying each part of speech (`noun`, `verb`, ...).
  final Map<String, List<int>> partsOfSpeech;

  /// Positions of entries carrying each topic or free-form tag.
  final Map<String, List<int>> tags;

  int get wordCount => sortedWords.length;

  Set<String> get levelKeys => levels.keys.toSet();

  Set<String> get posKeys => partsOfSpeech.keys.toSet();

  Set<String> get tagKeys => tags.keys.toSet();

  /// Number of entries tagged with CEFR [level].
  int countForLevel(String level) => levels[level]?.length ?? 0;

  /// The entry position for an exact [normalizedWord], or `null`.
  int? lookupPosition(String normalizedWord) {
    final i = _lowerBound(sortedWords, normalizedWord);
    if (i < sortedWords.length && sortedWords[i] == normalizedWord) {
      return sortedPositions[i];
    }
    return null;
  }

  /// Positions of every entry whose headword starts with [normalizedPrefix],
  /// in alphabetical order.
  List<int> prefixPositions(String normalizedPrefix) {
    final result = <int>[];
    for (var i = _lowerBound(sortedWords, normalizedPrefix);
        i < sortedWords.length;
        i++) {
      if (!sortedWords[i].startsWith(normalizedPrefix)) break;
      result.add(sortedPositions[i]);
    }
    return result;
  }

  /// Positions of entries at CEFR [level], in original load order.
  List<int> positionsForLevel(String level) =>
      List.unmodifiable(levels[level] ?? const []);

  /// Positions of entries with part of speech [pos], in original load order.
  List<int> positionsForPos(String pos) =>
      List.unmodifiable(partsOfSpeech[normalizeText(pos)] ?? const []);

  /// Positions of entries carrying tag [tag] (topic or free-form), in
  /// original load order.
  List<int> positionsForTag(String tag) =>
      List.unmodifiable(tags[normalizeText(tag)] ?? const []);

  /// Serialises the index for the import tool's sidecar assets.
  String toJsonString() => jsonEncode({
        'version': 1,
        'sorted': sortedWords,
        'sortedPos': sortedPositions,
        'levels': levels,
        'pos': partsOfSpeech,
        'tags': tags,
      });

  static Map<String, List<int>> _decodeMap(Object? raw) {
    final out = <String, List<int>>{};
    if (raw is Map<String, dynamic>) {
      for (final entry in raw.entries) {
        out[entry.key] = [
          for (final p in entry.value as List<dynamic>) (p as num).toInt(),
        ];
      }
    }
    return out;
  }

  /// First index in [sorted] whose value is `>= [value]` (lower bound).
  static int _lowerBound(List<String> sorted, String value) {
    var lo = 0;
    var hi = sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (sorted[mid].compareTo(value) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}
