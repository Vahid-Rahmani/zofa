import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/services/dictionary.dart';

void main() {
  group('GermanDictionary', () {
    test('contains hundreds of German entries', () {
      expect(GermanDictionary.wordCount, greaterThanOrEqualTo(300));
    });

    test('every level holds a rich word pool', () {
      for (final level in ['A1', 'A2', 'B1']) {
        final entries = GermanDictionary.byLevel(level);
        expect(entries.length, greaterThanOrEqualTo(80),
            reason: '$level should have at least 80 words, found ${entries.length}');
      }
    });

    test('every entry is complete and level-tagged', () {
      for (final entry in GermanDictionary.all) {
        expect(entry.word, isNotEmpty);
        expect(entry.translation, isNotEmpty,
            reason: '${entry.word} should have a Persian translation');
        expect(['A1', 'A2', 'B1'], contains(entry.level),
            reason: '${entry.word} should carry a valid level');
        expect(entry.partOfSpeech, isNotEmpty);
        expect(entry.example, isNotEmpty,
            reason: '${entry.word} should have a German example');
        expect(entry.exampleTranslation, isNotEmpty,
            reason: '${entry.word} example should have a Persian translation');
      }
    });

    test('headwords are unique', () {
      final words = GermanDictionary.all.map((e) => e.word).toList();
      expect(words.toSet().length, words.length);
    });

    test('lookup is case-insensitive and ignores punctuation', () {
      final hallo = GermanDictionary.lookup('hallo');
      expect(hallo, isNotNull);
      expect(hallo!.translation, 'سلام');

      expect(GermanDictionary.lookup('HALLO'), isNotNull);
      expect(GermanDictionary.lookup('Hallo,'), isNotNull);
      expect(GermanDictionary.lookup('danke'), isNotNull);
      expect(GermanDictionary.lookup('diesistkeinwort'), isNull);
    });

    test('translation() returns Persian or null', () {
      expect(GermanDictionary.translation('Wasser'), 'آب');
      expect(GermanDictionary.translation('wasser'), 'آب');
      expect(GermanDictionary.translation('xyzzy'), isNull);
    });

    test('byLevel filters entries', () {
      final b1 = GermanDictionary.byLevel('B1');
      expect(b1, isNotEmpty);
      expect(b1.every((e) => e.level == 'B1'), isTrue);
    });

    test('search matches German words and Persian translations', () {
      expect(GermanDictionary.search('Wasser'), isNotEmpty);
      final byPersian = GermanDictionary.search('آب');
      expect(byPersian, isNotEmpty);
      expect(byPersian.any((e) => e.word == 'Wasser'), isTrue);
      expect(byPersian.every((e) => e.translation.contains('آب')), isTrue);
      expect(byPersian.length, lessThan(GermanDictionary.wordCount),
          reason: 'a Persian query should filter, not return everything');
      expect(GermanDictionary.search(''), GermanDictionary.all);
    });

    test('German examples come with Persian translations', () {
      final entry = GermanDictionary.lookup('Wasser')!;
      expect(entry.example, 'Trink mehr Wasser jeden Tag.');
      expect(entry.exampleTranslation, isNotEmpty);
    });
  });
}
