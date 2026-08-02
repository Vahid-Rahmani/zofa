import '../models/dictionary_entry.dart';
import 'dictionary_data.dart';
import 'dictionary_service.dart';
import 'german_dictionary_data.dart';

/// The built-in English -> Persian dictionary.
abstract final class Dictionary {
  static final DictionaryService service =
      DictionaryService(DictionaryData.entries);

  static List<DictionaryEntry> get all => service.all;

  static int get wordCount => service.wordCount;

  static int get exampleCount => service.exampleCount;

  static DictionaryEntry? lookup(String word) => service.lookup(word);

  static String? translation(String word) => service.translation(word);

  static List<DictionaryEntry> byLevel(String level) =>
      service.byLevel(level);

  static List<DictionaryEntry> search(String query) =>
      service.search(query);
}

/// The built-in German -> Persian dictionary.
abstract final class GermanDictionary {
  static final DictionaryService service =
      DictionaryService(GermanDictionaryData.entries);

  static List<DictionaryEntry> get all => service.all;

  static int get wordCount => service.wordCount;

  static int get exampleCount => service.exampleCount;

  static DictionaryEntry? lookup(String word) => service.lookup(word);

  static String? translation(String word) => service.translation(word);

  static List<DictionaryEntry> byLevel(String level) =>
      service.byLevel(level);

  static List<DictionaryEntry> search(String query) =>
      service.search(query);
}
