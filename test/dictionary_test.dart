import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/dictionary_entry.dart';
import 'package:zova/data/services/dictionary.dart';
import 'package:zova/data/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryService dict;

  setUpAll(() async {
    dict = await Dictionary.service;
  });

  group('Dictionary', () {
    test('loads hundreds of entries from the bundled JSON asset', () {
      expect(dict.wordCount, greaterThanOrEqualTo(300));
    });

    test('every level holds a rich word pool', () {
      for (final level in ['A1', 'A2', 'B1']) {
        final entries = dict.byLevel(level);
        expect(entries.length, greaterThanOrEqualTo(80),
            reason: '$level should have at least 80 words, found ${entries.length}');
      }
    });

    test('every entry is complete and level-tagged', () {
      for (final entry in dict.all) {
        expect(entry.word, isNotEmpty);
        expect(['A1', 'A2', 'B1'], contains(entry.level),
            reason: '${entry.word} should carry a valid level');
        expect(entry.partOfSpeech, isNotEmpty);
        expect(entry.example, isNotEmpty,
            reason: '${entry.word} should have an example sentence');
      }
    });

    test('master dataset is slim: entries carry no baked translations', () {
      for (final entry in dict.entries) {
        final json = entry.toJson();
        expect(json.containsKey('translation'), isFalse);
        expect(json.containsKey('english_translation'), isFalse);
        expect(json.containsKey('persian_definition'), isFalse);
        expect(json.containsKey('persian_example'), isFalse);
      }
    });

    test('headwords are unique', () {
      final words = dict.all.map((e) => e.word).toList();
      expect(words.toSet().length, words.length);
    });

    test('lookup is case-insensitive and ignores punctuation', () {
      final entry = dict.lookup('hello');
      expect(entry, isNotNull);
      expect(entry!.example, isNotEmpty);

      expect(dict.lookup('HELLO'), isNotNull);
      expect(dict.lookup('hello,'), isNotNull);
      expect(dict.lookup('thank you'), isNotNull);
      expect(dict.lookup('thisisnotaword'), isNull);
    });

    test('byLevel filters entries', () {
      final a1 = dict.byLevel('A1');
      expect(a1, isNotEmpty);
      expect(a1.every((e) => e.level == 'A1'), isTrue);
    });

    test('search matches headwords and example sentences', () {
      expect(dict.search('water'), isNotEmpty);
      final byExample = dict.search('how are you');
      expect(byExample, isNotEmpty);
      expect(byExample.any((e) => e.word == 'hello'), isTrue,
          reason: 'the "hello" entry must surface via its example sentence');
      expect(byExample.length, lessThan(dict.wordCount),
          reason: 'an example query should filter, not return everything');
      expect(dict.search(''), dict.all);
    });

    test('entries round-trip through JSON', () {
      final entry = dict.lookup('water')!;
      final restored = DictionaryEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored.word, entry.word);
      expect(restored.example, entry.example);
      expect(restored.level, entry.level);
      expect(restored.gender, entry.gender);
    });

    test('is JSON-serialisable end to end', () {
      final entries = dict.entries;
      final json = jsonEncode([for (final e in entries) e.toJson()]);
      final reloaded = DictionaryService.fromJsonString(json);
      expect(reloaded.wordCount, dict.wordCount);
      expect(reloaded.lookup('water')?.example, isNotEmpty);
    });
  });
}
