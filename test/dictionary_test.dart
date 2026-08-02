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
        expect(entry.translation, isNotEmpty,
            reason: '${entry.word} should have a Persian translation');
        expect(['A1', 'A2', 'B1'], contains(entry.level),
            reason: '${entry.word} should carry a valid level');
        expect(entry.partOfSpeech, isNotEmpty);
        expect(entry.example, isNotEmpty,
            reason: '${entry.word} should have an example');
        expect(entry.exampleTranslation, isNotEmpty,
            reason: '${entry.word} example should have a Persian translation');
      }
    });

    test('headwords are unique', () {
      final words = dict.all.map((e) => e.word).toList();
      expect(words.toSet().length, words.length);
    });

    test('lookup is case-insensitive and ignores punctuation', () {
      final entry = dict.lookup('hello');
      expect(entry, isNotNull);
      expect(entry!.translation, 'سلام');

      expect(dict.lookup('HELLO'), isNotNull);
      expect(dict.lookup('hello,'), isNotNull);
      expect(dict.lookup('thank you'), isNotNull);
      expect(dict.lookup('thisisnotaword'), isNull);
    });

    test('translation() returns Persian or null', () {
      expect(dict.translation('water'), 'آب');
      expect(dict.translation('Water'), 'آب');
      expect(dict.translation('xyzzy'), isNull);
    });

    test('byLevel filters entries', () {
      final a1 = dict.byLevel('A1');
      expect(a1, isNotEmpty);
      expect(a1.every((e) => e.level == 'A1'), isTrue);
    });

    test('search matches English words and Persian translations', () {
      expect(dict.search('water'), isNotEmpty);
      final byPersian = dict.search('آب');
      expect(byPersian, isNotEmpty);
      expect(byPersian.any((e) => e.word == 'water'), isTrue);
      expect(
        byPersian.any((e) => e.translation.contains('آب')),
        isTrue,
        reason: 'translation matches must still surface',
      );
      expect(byPersian.length, lessThan(dict.wordCount),
          reason: 'a Persian query should filter, not return everything');
      expect(dict.search(''), dict.all);
    });

    test('entries round-trip through JSON', () {
      final entry = dict.lookup('water')!;
      final restored = DictionaryEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored.word, entry.word);
      expect(restored.translation, entry.translation);
      expect(restored.level, entry.level);
      expect(restored.gender, entry.gender);
    });

    test('is JSON-serialisable end to end', () {
      final entries = dict.entries;
      final json = jsonEncode([for (final e in entries) e.toJson()]);
      final reloaded = DictionaryService.fromJsonString(json);
      expect(reloaded.wordCount, dict.wordCount);
      expect(reloaded.lookup('water')?.translation, 'آب');
    });
  });
}
