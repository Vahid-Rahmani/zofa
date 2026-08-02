import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/services/dictionary.dart';

void main() {
  group('Dictionary', () {
    test('contains hundreds of entries', () {
      expect(Dictionary.wordCount, greaterThanOrEqualTo(300));
    });

    test('every level holds a rich word pool', () {
      for (final level in ['A1', 'A2', 'B1']) {
        final entries = Dictionary.byLevel(level);
        expect(entries.length, greaterThanOrEqualTo(80),
            reason: '$level should have at least 80 words, found ${entries.length}');
      }
    });

    test('every entry is complete and level-tagged', () {
      for (final entry in Dictionary.all) {
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
      final words = Dictionary.all.map((e) => e.word).toList();
      expect(words.toSet().length, words.length);
    });

    test('lookup is case-insensitive and ignores punctuation', () {
      final entry = Dictionary.lookup('hello');
      expect(entry, isNotNull);
      expect(entry!.translation, 'سلام');

      expect(Dictionary.lookup('HELLO'), isNotNull);
      expect(Dictionary.lookup('hello,'), isNotNull);
      expect(Dictionary.lookup('thank you'), isNotNull);
      expect(Dictionary.lookup('thisisnotaword'), isNull);
    });

    test('translation() returns Persian or null', () {
      expect(Dictionary.translation('water'), 'آب');
      expect(Dictionary.translation('Water'), 'آب');
      expect(Dictionary.translation('xyzzy'), isNull);
    });

    test('byLevel filters entries', () {
      final a1 = Dictionary.byLevel('A1');
      expect(a1, isNotEmpty);
      expect(a1.every((e) => e.level == 'A1'), isTrue);
    });

    test('search matches English words and Persian translations', () {
      expect(Dictionary.search('water'), isNotEmpty);
      final byPersian = Dictionary.search('آب');
      expect(byPersian, isNotEmpty);
      expect(byPersian.any((e) => e.word == 'water'), isTrue);
      expect(byPersian.every((e) => e.translation.contains('آب')), isTrue);
      expect(byPersian.length, lessThan(Dictionary.wordCount),
          reason: 'a Persian query should filter, not return everything');
      expect(Dictionary.search(''), Dictionary.all);
    });
  });
}
