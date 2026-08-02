import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/services/translation_backend.dart';

void main() {
  group('OnlineTranslationBackend.parseGoogleResponse', () {
    test('parses gloss, part of speech and alternate terms', () {
      final body = jsonEncode({
        'sentences': [
          {'trans': 'سیب', 'orig': 'apple'},
        ],
        'dict': [
          {
            'pos': 'noun',
            'terms': ['سیب', 'اپل'],
            'entry': [
              {'word': 'apple', 'reverse_translation': ['سیب']},
              {'word': 'apple', 'reverse_translation': ['اپل']},
            ],
          },
        ],
      });

      final result = OnlineTranslationBackend.parseGoogleResponse(
        body,
        word: 'apple',
        source: 'en',
        target: 'fa',
      );

      expect(result, isNotNull);
      expect(result!.translation, 'سیب');
      expect(result.partOfSpeech, 'noun');
      expect(result.alternates, contains('اپل'));
      expect(result.alternates, isNot(contains('سیب')),
          reason: 'the primary gloss is not an alternate');
    });

    test('joins multiple sentence fragments', () {
      final body = jsonEncode({
        'sentences': [
          {'trans': 'سلام', 'orig': 'hello'},
          {'trans': ' دنیا', 'orig': ' world'},
        ],
      });
      final result = OnlineTranslationBackend.parseGoogleResponse(
        body,
        word: 'hello world',
        source: 'en',
        target: 'fa',
      );
      expect(result!.translation, 'سلام دنیا');
      expect(result.partOfSpeech, isNull);
    });

    test('returns null for an unknown or malformed response', () {
      expect(
        OnlineTranslationBackend.parseGoogleResponse(
          'not json',
          word: 'x',
          source: 'en',
          target: 'fa',
        ),
        isNull,
      );
      expect(
        OnlineTranslationBackend.parseGoogleResponse(
          jsonEncode({'sentences': []}),
          word: 'x',
          source: 'en',
          target: 'fa',
        ),
        isNull,
      );
    });
  });

  group('Wiktionary parsing', () {
    test('genderFromSummary reads the leading German article', () {
      expect(
        OnlineTranslationBackend.genderFromSummary({
          'title': 'Haus',
          'extract': 'Das Haus (Mehrzahl: die Häuser) ist ein Gebäude …',
        }),
        'das',
      );
      expect(
        OnlineTranslationBackend.genderFromSummary({
          'title': 'Apfel',
          'extract': 'Der Apfel ist die Frucht des Apfelbaums.',
        }),
        'der',
      );
      expect(
        OnlineTranslationBackend.genderFromSummary({
          'title': 'x',
          'extract': 'Kein Artikel hier.',
        }),
        isNull,
      );
    });

    test('firstDefinition returns the first definition and example', () {
      final json = {
        'de': [
          {
            'partOfSpeech': 'Substantiv',
            'language': 'Deutsch',
            'definitions': [
              {
                'definition': 'Frucht des Apfelbaums',
                'parsedExamples': [
                  {'example': 'Der Apfel ist reif.'},
                ],
              },
            ],
          },
        ],
      };
      final result = OnlineTranslationBackend.firstDefinition(json, 'de');
      expect(result.definition, 'Frucht des Apfelbaums');
      expect(result.example, 'Der Apfel ist reif.');
    });

    test('firstDefinition skips empty definitions', () {
      final json = {
        'en': [
          {
            'definitions': [
              {'definition': ' '},
              {
                'definition': 'A round fruit.',
                'parsedExamples': [],
              },
            ],
          },
        ],
      };
      final result = OnlineTranslationBackend.firstDefinition(json, 'en');
      expect(result.definition, 'A round fruit.');
      expect(result.example, isNull);
    });
  });
}
