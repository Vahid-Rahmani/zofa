import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/dictionary_entry.dart';
import 'package:zova/data/models/exercise.dart';
import 'package:zova/data/services/dictionary.dart';
import 'package:zova/data/services/dictionary_index.dart';
import 'package:zova/data/services/dictionary_service.dart';
import 'package:zova/data/services/seed_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryService dict;

  setUpAll(() async {
    dict = await Dictionary.service;
  });

  group('DictionaryIndex', () {
    test('round-trips through its serialised sidecar', () {
      final index = DictionaryIndex.build(dict.entries);
      final restored = DictionaryIndex.fromJsonString(index.toJsonString());

      expect(restored.wordCount, index.wordCount);
      expect(restored.levelKeys, index.levelKeys);
      expect(restored.posKeys, contains('noun'));
      expect(restored.tagKeys, contains('greetings'));
      expect(restored.lookupPosition('hello'), index.lookupPosition('hello'));
      expect(restored.lookupPosition('water'), isNotNull);
      expect(restored.lookupPosition('notaword'), isNull);
      expect(restored.prefixPositions('wat'), index.prefixPositions('wat'));
      expect(restored.countForLevel('A1'), index.countForLevel('A1'));
    });
  });

  group('searchPaged', () {
    test('pages through the full dictionary in alphabetical order', () {
      const page = 40;
      final first = dict.searchPaged(const DictionaryQuery(limit: page));
      expect(first.items.length, page);
      expect(first.total, dict.wordCount);

      final second = dict.searchPaged(
        const DictionaryQuery(offset: page, limit: page),
      );
      expect(second.items.length, page);
      expect(second.items.first.word, isNot(first.items.last.word));
      expect(
        {...first.items, ...second.items}.length,
        page * 2,
        reason: 'pages must not overlap',
      );
    });

    test('prefix search matches headwords and reports total', () {
      final result = dict.searchPaged(const DictionaryQuery(query: 'wa', limit: 10));
      expect(result.total, greaterThanOrEqualTo(1));
      expect(result.items.every((e) => e.word.startsWith('wa')), isTrue);
    });

    test('queries scan headwords and example sentences', () {
      final result =
          dict.searchPaged(const DictionaryQuery(query: 'how are you', limit: 20));
      expect(result.total, greaterThanOrEqualTo(1));
      expect(result.items.any((e) => e.word == 'hello'), isTrue);
      final exampleOnly =
          dict.entries.where((e) => e.example.contains('how are you')).length;
      expect(result.total, greaterThanOrEqualTo(exampleOnly),
          reason: 'search must still surface every example match');
      for (final e in result.items) {
        expect(
          e.word.toLowerCase().contains('how are you') ||
              e.example.toLowerCase().contains('how are you'),
          isTrue,
          reason: '"${e.word}" should match the query in some field',
        );
      }
    });

    test('level + part-of-speech filters narrow results', () {
      final result = dict.searchPaged(
        const DictionaryQuery(levels: ['A2'], partsOfSpeech: ['noun'], limit: 20),
      );
      expect(result.total, greaterThanOrEqualTo(1));
      for (final e in result.items) {
        expect(e.level, 'A2');
        expect(e.partOfSpeech, 'noun');
      }
      expect(result.total, lessThanOrEqualTo(dict.countForLevel('A2')));
    });

    test('tag filters match entries carrying that topic', () {
      final result = dict.searchPaged(
        const DictionaryQuery(tags: ['greetings'], limit: 20),
      );
      expect(result.total, greaterThanOrEqualTo(1));
      for (final e in result.items) {
        expect(e.topics, contains('greetings'));
      }
    });

    test('countForLevel exposes every CEFR bucket', () {
      expect(dict.countForLevel('A1'), greaterThanOrEqualTo(80));
      for (final level in kCefrLevels) {
        expect(dict.countForLevel(level), greaterThanOrEqualTo(0));
      }
    });
  });

  group('course-from-dictionary', () {
    test('every course word exists in the dictionary', () async {
      final course = await SeedContent.englishCourse();
      final words = <String>{
        for (final level in course.levels)
          for (final lesson in level.lessons)
            for (final exercise in lesson.exercises)
              if (exercise.type == ExerciseType.flashcard) ...exercise.words,
      };
      expect(words, isNotEmpty);
      for (final word in words) {
        expect(dict.lookup(word), isNotNull,
            reason: '"$word" should exist in the dictionary');
      }
    });
  });

  group('scale', () {
    test('a 100k-entry dictionary stays correct and fast', () {
      final buildWatch = Stopwatch()..start();
      final service = DictionaryService(_generate(100000));
      final buildMs = buildWatch.elapsedMilliseconds;

      expect(service.wordCount, 100000);

      final searchWatch = Stopwatch()..start();

      final hit = service.lookup('word050000');
      expect(hit, isNotNull);
      expect(hit!.example, 'Example for word 50000.');
      expect(service.lookup('nothere'), isNull);

      final prefix = service.searchPaged(
        const DictionaryQuery(query: 'word01', limit: 20),
      );
      expect(prefix.items.length, 20);
      expect(prefix.items.every((e) => e.word.startsWith('word01')), isTrue);

      final byExample = service.searchPaged(
        const DictionaryQuery(query: 'Example for word', limit: 50),
      );
      expect(byExample.total, greaterThan(0));
      expect(byExample.items.length, 50);

      final filtered = service.searchPaged(
        const DictionaryQuery(
          levels: ['A1'],
          partsOfSpeech: ['noun'],
          tags: ['common'],
          limit: 10,
        ),
      );
      for (final e in filtered.items) {
        expect(e.level, 'A1');
        expect(e.partOfSpeech, 'noun');
        expect(e.tags, contains('common'));
      }

      final searchMs = searchWatch.elapsedMilliseconds;
      expect(searchMs, lessThan(5000),
          reason: 'indexed search should be fast even at 100k entries');
      debugPrint('100k build=${buildMs}ms, search suite=${searchMs}ms');
    });
  });

  group('validation and resilience', () {
    test('validate reports each missing required field', () {
      final errors = DictionaryEntry.validate({
        'word': 'water',
        'part_of_speech': 'noun',
        'level': 'A1',
        'example': 'Drink water.',
      });
      expect(errors, isEmpty);

      final missing = DictionaryEntry.validate({'example': 'Hi.'});
      expect(missing, contains('missing or empty "word"'));
      expect(missing, contains('missing or empty "part_of_speech"'));
      expect(missing, contains('missing or empty "level"'));
      expect(missing, isNot(contains('missing or empty "example"')));
    });

    test('tryParse returns null for malformed rows and parses valid ones', () {
      expect(DictionaryEntry.tryParse({'word': 'hi'}), isNull);
      expect(
        DictionaryEntry.tryParse({
          'word': 'hi',
          'part_of_speech': 'interjection',
          'level': 'A1',
          'example': 'Hi!',
        }),
        isNotNull,
      );
    });

    test('fromJsonString skips invalid rows without crashing', () {
      final service = DictionaryService.fromJsonString(jsonEncode([
        {
          'word': 'good',
          'part_of_speech': 'adjective',
          'level': 'A1',
          'example': 'Have a good day!',
        },
        {'word': 'broken'},
        'not-a-map',
        {
          'word': 'night',
          'part_of_speech': 'noun',
          'level': 'A1',
          'example': 'Good night!',
        },
      ]));
      expect(service.wordCount, 2);
      expect(service.lookup('good'), isNotNull);
      expect(service.lookup('night'), isNotNull);
      expect(DictionaryService.lastSkippedCount, 2);
    });

    test('byId resolves ids and derived slugs; unknown ids are null', () {
      final service = DictionaryService.fromJsonString(jsonEncode([
        {
          'id': 'custom-id',
          'word': 'hello',
          'part_of_speech': 'interjection',
          'level': 'A1',
          'example': 'Hello!',
        },
        {
          'word': 'Good morning',
          'part_of_speech': 'phrase',
          'level': 'A1',
          'example': 'Good morning, everyone!',
        },
      ]));
      expect(service.byId('custom-id')!.word, 'hello');
      expect(service.byId('good-morning')!.word, 'Good morning');
      expect(service.byId('unknown'), isNull);
    });

    test('new metadata fields round-trip through JSON', () {
      const entry = DictionaryEntry(
        word: 'der Apfel',
        partOfSpeech: 'noun',
        level: 'A1',
        example: 'Der Apfel ist rot.',
        lemma: 'der Apfel',
        language: 'de',
        phonetic: 'ˈapfl̩',
        gender: 'der',
        plural: 'die Äpfel',
        synonyms: ['der Apfel'],
        antonyms: [],
        relatedWords: ['der Apfelbaum'],
        irregularForms: [],
        topics: ['food'],
        tags: ['fruit'],
        frequency: 900,
        audioRef: 'assets/audio/appfel.mp3',
        imageRef: 'assets/img/apple.png',
      );
      final restored = DictionaryEntry.fromJson(entry.toJson());
      expect(restored.effectiveId, 'der-apfel');
      expect(restored.lemma, 'der Apfel');
      expect(restored.language, 'de');
      expect(restored.plural, 'die Äpfel');
      expect(restored.synonyms, ['der Apfel']);
      expect(restored.relatedWords, ['der Apfelbaum']);
      expect(restored.audioRef, 'assets/audio/appfel.mp3');
      expect(restored.imageRef, 'assets/img/apple.png');
      expect(restored.toJson()['synonyms'], ['der Apfel']);
    });

    test('legacy gloss keys in JSON are ignored by the slim model', () {
      final entry = DictionaryEntry.fromJson({
        'word': 'hallo',
        'part_of_speech': 'interjection',
        'level': 'A1',
        'example': 'Hallo!',
        'translation': 'سلام',
        'english_translation': 'hello',
        'persian_example': 'سلام!',
      });
      expect(entry.word, 'hallo');
      expect(entry.example, 'Hallo!');
      expect(entry.toJson().containsKey('translation'), isFalse);
      expect(entry.toJson().containsKey('persian_example'), isFalse);
    });
  });
}

List<DictionaryEntry> _generate(int count) {
  const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  const partsOfSpeech = ['noun', 'verb', 'adjective'];
  const topics = ['core', 'daily'];
  return [
    for (var i = 0; i < count; i++)
      DictionaryEntry(
        word: 'word${i.toString().padLeft(6, '0')}',
        partOfSpeech: partsOfSpeech[i % partsOfSpeech.length],
        level: levels[i % levels.length],
        example: 'Example for word $i.',
        topics: [topics[i % topics.length]],
        tags: [i.isEven ? 'common' : 'rare'],
        frequency: count - i,
      ),
  ];
}
