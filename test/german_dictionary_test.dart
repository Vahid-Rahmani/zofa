import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/services/dictionary.dart';
import 'package:zova/data/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryService dict;

  setUpAll(() async {
    dict = await GermanDictionary.service;
  });

  group('GermanDictionary', () {
    test('loads hundreds of German entries from the bundled JSON asset', () {
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
            reason: '${entry.word} should have a German example');
        expect(entry.exampleTranslation, isNotEmpty,
            reason: '${entry.word} example should have a Persian translation');
      }
    });

    test('headwords are unique', () {
      final words = dict.all.map((e) => e.word).toList();
      expect(words.toSet().length, words.length);
    });

    test('nouns carry their grammatical gender', () {
      expect(dict.lookup('Wasser')!.gender, 'das');
      expect(dict.lookup('Frau')!.gender, 'die');
      expect(dict.lookup('Mann')!.gender, 'der');
      expect(dict.lookup('Buch')!.gender, 'das');

      expect(dict.lookup('hallo')!.gender, isNull,
          reason: 'interjections have no gender');
      expect(dict.lookup('trinken')!.gender, isNull,
          reason: 'verbs have no gender');
    });

    test('lookup is case-insensitive and ignores punctuation', () {
      final hallo = dict.lookup('hallo');
      expect(hallo, isNotNull);
      expect(hallo!.translation, 'سلام');

      expect(dict.lookup('HALLO'), isNotNull);
      expect(dict.lookup('Hallo,'), isNotNull);
      expect(dict.lookup('danke'), isNotNull);
      expect(dict.lookup('diesistkeinwort'), isNull);
    });

    test('translation() returns Persian or null', () {
      expect(dict.translation('Wasser'), 'آب');
      expect(dict.translation('wasser'), 'آب');
      expect(dict.translation('xyzzy'), isNull);
    });

    test('byLevel filters entries', () {
      final b1 = dict.byLevel('B1');
      expect(b1, isNotEmpty);
      expect(b1.every((e) => e.level == 'B1'), isTrue);
    });

    test('search matches German words and Persian translations', () {
      expect(dict.search('Wasser'), isNotEmpty);
      final byPersian = dict.search('آب');
      expect(byPersian, isNotEmpty);
      expect(byPersian.any((e) => e.word == 'Wasser'), isTrue);
      expect(byPersian.every((e) => e.translation.contains('آب')), isTrue);
      expect(byPersian.length, lessThan(dict.wordCount),
          reason: 'a Persian query should filter, not return everything');
      expect(dict.search(''), dict.all);
    });

    test('German examples come with Persian translations', () {
      final entry = dict.lookup('Wasser')!;
      expect(entry.example, 'Trink mehr Wasser jeden Tag.');
      expect(entry.exampleTranslation, isNotEmpty);
    });
  });
}
