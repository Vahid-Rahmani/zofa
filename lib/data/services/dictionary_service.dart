import 'dart:convert';

import 'package:flutter/foundation.dart'
    show SynchronousFuture, compute, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../models/dictionary_entry.dart';
import 'dictionary_index.dart';
import 'normalize.dart';

/// CEFR levels offered by the dictionary filters, in ascending order.
const List<String> kCefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/// Immutable in-memory engine over a set of [DictionaryEntry]s for one source
/// language, backed by a [DictionaryIndex] for O(log n) lookups, headword
/// prefix search and level / part-of-speech / tag filters.
///
/// Big dumps are parsed off the UI thread in a background isolate (see
/// [loadPack]) so tens or hundreds of thousands of entries load without
/// janking the app. The engine powers the Dictionary tab, the word-tap
/// lookups in the reader and the lesson builder.
class DictionaryService {
  DictionaryService(List<DictionaryEntry> entries)
      : this._(entries, DictionaryIndex.build(entries));

  DictionaryService._(this._entries, this._index);

  /// Parses a JSON array of entry objects produced by `DictionaryEntry.toJson`
  /// and builds its in-memory index synchronously (used for test data and
  /// small seeds). Malformed rows are skipped, never thrown.
  factory DictionaryService.fromJsonString(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    final entries = _parseEntries(decoded);
    return DictionaryService._(entries, DictionaryIndex.build(entries));
  }

  /// Parses an entries JSON document and, when [indexJson] is non-null, adopts
  /// the pre-built [DictionaryIndex] written by the import tool instead of
  /// rebuilding it from the entries. Malformed rows are skipped, never thrown.
  factory DictionaryService.fromPack(String entriesJson, String? indexJson) {
    final decoded = jsonDecode(entriesJson) as List<dynamic>;
    final entries = _parseEntries(decoded);
    final index = (indexJson == null || indexJson.isEmpty)
        ? DictionaryIndex.build(entries)
        : DictionaryIndex.fromJsonString(indexJson);
    return DictionaryService._(entries, index);
  }

  /// Number of rows dropped by the most recent [fromJsonString] / [fromPack]
  /// parse because they failed [DictionaryEntry.validate]. Useful for import
  /// sanity checks and tests; only updated by parsing on this isolate.
  @visibleForTesting
  static int lastSkippedCount = 0;

  static List<DictionaryEntry> _parseEntries(List<dynamic> decoded) {
    var skipped = 0;
    final entries = <DictionaryEntry>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      final entry = DictionaryEntry.tryParse(item);
      if (entry == null) {
        skipped++;
        continue;
      }
      entries.add(entry);
    }
    lastSkippedCount = skipped;
    return entries;
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

  /// Asynchronously loads and parses a bundled dictionary pack. When a test
  /// seeded [entriesPath] via [seedAsset] the value completes synchronously.
  ///
  /// The heavy JSON parsing happens in a background isolate so a large dump
  /// never blocks the UI thread.
  static Future<DictionaryService> loadPack({
    required String entriesPath,
    String? indexPath,
  }) {
    final override = _assetOverrides[entriesPath];
    if (override != null) {
      return SynchronousFuture<DictionaryService>(
        DictionaryService.fromJsonString(override),
      );
    }
    return _loadFromBundle(entriesPath, indexPath);
  }

  static Future<DictionaryService> _loadFromBundle(
    String entriesPath,
    String? indexPath,
  ) async {
    final entriesJson = await rootBundle.loadString(entriesPath);
    final indexJson =
        indexPath == null ? null : await rootBundle.loadString(indexPath);
    return compute(_parsePack, _PackArgs(entriesJson, indexJson));
  }

  final List<DictionaryEntry> _entries;
  final DictionaryIndex _index;

  late final Map<String, DictionaryEntry> _byId = {
    for (final e in _entries) e.effectiveId: e,
  };

  /// Every entry in its original (curated) order.
  List<DictionaryEntry> get entries => List.unmodifiable(_entries);

  /// Every entry, sorted alphabetically by headword.
  List<DictionaryEntry> get all =>
      List.unmodifiable([for (final p in _index.sortedPositions) _entries[p]]);

  /// Number of headwords in the dictionary.
  int get wordCount => _entries.length;

  /// Number of entries that teach an example sentence.
  int get exampleCount => _entries.where((e) => e.example.isNotEmpty).length;

  /// CEFR levels present in the dictionary (`A1`, `A2`, ...).
  Set<String> get levelKeys => _index.levelKeys;

  /// Parts of speech present in the dictionary.
  Set<String> get posKeys => _index.posKeys;

  /// Topic / free-form tags present in the dictionary.
  Set<String> get tagKeys => _index.tagKeys;

  /// Looks up [word] case-insensitively, ignoring punctuation and articles.
  DictionaryEntry? lookup(String word) {
    final normalized = normalizeText(word);
    if (normalized.isEmpty) return null;
    final position = _index.lookupPosition(normalized);
    return position == null ? null : _entries[position];
  }

  /// Looks up an entry by its stable [effectiveId] ([DictionaryEntry.id] when
  /// present, otherwise the slug of the headword). O(1).
  DictionaryEntry? byId(String id) => _byId[id];

  late final Map<String, DictionaryEntry> _byConcept = {
    for (final e in _entries) e.effectiveConcept: e,
  };

  /// Looks up an entry by its shared [DictionaryEntry.concept] id, which links
  /// the same idea across target-language dictionaries. O(1).
  DictionaryEntry? byConcept(String concept) => _byConcept[concept];

  /// Whether an entry for [concept] exists in this dictionary.
  bool hasConcept(String concept) => _byConcept.containsKey(concept);

  /// Filters entries by CEFR [level] (`A1`, `A2`, ...).
  List<DictionaryEntry> byLevel(String level) => List.unmodifiable(
      [for (final p in _index.positionsForLevel(level)) _entries[p]]);

  /// Number of entries at CEFR [level] — O(1) via the index.
  int countForLevel(String level) => _index.countForLevel(level);

  /// Number of entries with part of speech [pos].
  int countForPos(String pos) => _index.positionsForPos(pos).length;

  /// Number of entries carrying tag [tag] (topic or free-form).
  int countForTag(String tag) => _index.positionsForTag(tag).length;

  /// Entries carrying tag [tag] (topic or free-form).
  List<DictionaryEntry> byTag(String tag) => List.unmodifiable(
      [for (final p in _index.positionsForTag(tag)) _entries[p]]);

  /// Fuzzy search across headwords, example sentences and the other
  /// target-language facts (synonyms, related words, topics). Linear scan kept
  /// for compatibility with small datasets; use [searchPaged] for paginated,
  /// indexed queries.
  List<DictionaryEntry> search(String query) {
    final q = normalizeText(query);
    if (q.isEmpty) return all;
    return List.unmodifiable(_entries.where((e) => _matchesText(e, q)));
  }

  /// Paginated, filtered search for the Dictionary UI.
  ///
  /// Latin headword queries are narrowed to the index's prefix table
  /// (O(log n + k)); other queries fall back to a full scan over example
  /// sentences and the remaining target-language facts. Filters (level, part
  /// of speech, tags) are applied on the narrowed candidates, then
  /// [DictionaryQuery.offset] / [DictionaryQuery.limit] page the results. The
  /// result reports the total match count so the UI can drive infinite
  /// scrolling.
  DictionarySearchResult searchPaged(DictionaryQuery query) {
    final q = normalizeText(query.query);
    final headwordQuery = q.isNotEmpty && isHeadwordQuery(q);
    final levelFilter =
        query.levels.isEmpty ? null : query.levels.toSet();
    final posFilter =
        query.partsOfSpeech.isEmpty ? null : query.partsOfSpeech.toSet();
    final tagFilter = query.tags.isEmpty ? null : query.tags.toSet();

    final positions = q.isEmpty
        ? _index.sortedPositions
        : headwordQuery
            ? _index.prefixPositions(q)
            : List<int>.generate(_entries.length, (i) => i);

    final matched = <int>[];
    for (final position in positions) {
      final entry = _entries[position];
      if (levelFilter != null && !levelFilter.contains(entry.level)) continue;
      if (posFilter != null &&
          !posFilter.contains(normalizeText(entry.partOfSpeech))) {
        continue;
      }
      if (tagFilter != null && !_hasAnyTag(entry, tagFilter)) continue;
      if (!headwordQuery && q.isNotEmpty && !_matchesText(entry, q)) continue;
      matched.add(position);
    }

    final total = matched.length;
    final start = query.offset.clamp(0, total);
    final effectiveLimit = query.limit < 0 ? total : query.limit;
    final end = (start + effectiveLimit).clamp(start, total);
    return DictionarySearchResult(
      items: [for (var i = start; i < end; i++) _entries[matched[i]]],
      total: total,
    );
  }

  bool _hasAnyTag(DictionaryEntry entry, Set<String> tagFilter) {
    for (final t in entry.topics) {
      if (tagFilter.contains(normalizeText(t))) return true;
    }
    for (final t in entry.tags) {
      if (tagFilter.contains(normalizeText(t))) return true;
    }
    return false;
  }

  bool _matchesText(DictionaryEntry entry, String q) =>
      normalizeText(entry.word).contains(q) ||
      normalizeText(entry.example).contains(q) ||
      normalizeText(entry.effectiveLemma).contains(q) ||
      normalizeText(entry.plural ?? '').contains(q) ||
      entry.synonyms.any((s) => normalizeText(s).contains(q)) ||
      entry.antonyms.any((a) => normalizeText(a).contains(q)) ||
      entry.relatedWords.any((r) => normalizeText(r).contains(q)) ||
      entry.topics.any((t) => normalizeText(t).contains(q)) ||
      entry.tags.any((t) => normalizeText(t).contains(q));
}

/// Inputs for the background-isolate pack parse.
class _PackArgs {
  const _PackArgs(this.entriesJson, this.indexJson);

  final String entriesJson;
  final String? indexJson;
}

/// Top-level callback for [compute]: decodes the entries asset, attaches the
/// pre-built index if one was shipped, and returns the ready [DictionaryService].
DictionaryService _parsePack(_PackArgs args) =>
    DictionaryService.fromPack(args.entriesJson, args.indexJson);

/// A single paginated search request against a [DictionaryService].
class DictionaryQuery {
  const DictionaryQuery({
    this.query = '',
    this.levels = const [],
    this.partsOfSpeech = const [],
    this.tags = const [],
    this.offset = 0,
    this.limit = 50,
  });

  /// Search text; empty means "all entries".
  final String query;

  /// CEFR levels to include; empty means all levels.
  final List<String> levels;

  /// Parts of speech to include; empty means all.
  final List<String> partsOfSpeech;

  /// Tags (topics or free-form) any of which an entry must carry.
  final List<String> tags;

  /// First result to return (for infinite scrolling).
  final int offset;

  /// Maximum number of results; a negative value means "no limit".
  final int limit;

  DictionaryQuery copyWith({
    String? query,
    List<String>? levels,
    List<String>? partsOfSpeech,
    List<String>? tags,
    int? offset,
    int? limit,
  }) {
    return DictionaryQuery(
      query: query ?? this.query,
      levels: levels ?? this.levels,
      partsOfSpeech: partsOfSpeech ?? this.partsOfSpeech,
      tags: tags ?? this.tags,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

/// The outcome of a [DictionaryService.searchPaged] call.
class DictionarySearchResult {
  const DictionarySearchResult({required this.items, required this.total});

  /// The page of matching entries.
  final List<DictionaryEntry> items;

  /// Total number of matches across all pages.
  final int total;
}
