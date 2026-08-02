import 'dictionary_service.dart';

/// The built-in English -> Persian dictionary, loaded lazily from the bundled
/// JSON asset. Await [service] once and reuse the returned [DictionaryService]
/// for all lookups and searches.
abstract final class Dictionary {
  static const String _assetPath = 'assets/dictionary/english.json';

  static Future<DictionaryService>? _cache;

  /// Memoised async loader: resolves to the shared [DictionaryService] the
  /// first time it is awaited, then returns the same instance.
  static Future<DictionaryService> get service =>
      _cache ??= DictionaryService.loadAsset(_assetPath);
}

/// The built-in German -> Persian dictionary, loaded lazily from the bundled
/// JSON asset. Entries for German nouns carry their grammatical gender
/// (`der`/`die`/`das`) so courses and the UI can teach articles.
abstract final class GermanDictionary {
  static const String _assetPath = 'assets/dictionary/german.json';

  static Future<DictionaryService>? _cache;

  /// Memoised async loader for the German dictionary.
  static Future<DictionaryService> get service =>
      _cache ??= DictionaryService.loadAsset(_assetPath);
}
