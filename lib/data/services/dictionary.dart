import '../models/dictionary_entry.dart';
import 'dictionary_data.dart';

/// The built-in English -> Persian dictionary.
///
/// Indexed in memory from [DictionaryData]. Powers the Dictionary tab, the
/// word-tap lookups in the reader and the lesson builder.
abstract final class Dictionary {
  static final Map<String, DictionaryEntry> _byWord = {
    for (final entry in DictionaryData.entries) entry.word: entry,
  };

  /// Every entry, sorted alphabetically.
  static List<DictionaryEntry> get all => List.unmodifiable(
        [...DictionaryData.entries]..sort((a, b) => a.word.compareTo(b.word)),
      );

  /// Number of headwords in the dictionary.
  static int get wordCount => DictionaryData.entries.length;

  /// Number of entries that teach an English example sentence.
  static int get exampleCount =>
      DictionaryData.entries.where((e) => e.example.isNotEmpty).length;

  /// Looks up [word] case-insensitively, ignoring punctuation and articles.
  static DictionaryEntry? lookup(String word) {
    final normalized = _normalize(word);
    if (normalized.isEmpty) return null;
    return _byWord[normalized];
  }

  /// Convenience: the Persian translation of [word], when known.
  static String? translation(String word) => lookup(word)?.translation;

  /// Filters entries by CEFR [level] (`A1`, `A2`, `B1`).
  static List<DictionaryEntry> byLevel(String level) => List.unmodifiable(
        DictionaryData.entries.where((e) => e.level == level),
      );

  /// Fuzzy search across headwords, translations and examples.
  static List<DictionaryEntry> search(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return all;
    return List.unmodifiable(
      DictionaryData.entries.where((e) =>
          e.word.contains(q) ||
          e.translation.contains(q) ||
          e.example.toLowerCase().contains(q)),
    );
  }

  static String _normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z\u00e4\u00e9\u00fc\s]+"), ' ')
        .trim()
        .replaceAll(RegExp(r"\s{2,}"), ' ');
  }
}
