import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/translation_language.dart';
import 'package:zova/data/models/translation_result.dart';

void main() {
  group('TranslationLanguage', () {
    test('byCode resolves known languages and their direction', () {
      expect(TranslationLanguage.byCode('fa')?.isRtl, isTrue);
      expect(TranslationLanguage.byCode('ar')?.isRtl, isTrue);
      expect(TranslationLanguage.byCode('en')?.isRtl, isFalse);
      expect(TranslationLanguage.byCode('de')?.label, 'Deutsch');
      expect(TranslationLanguage.byCode('xx'), isNull);
    });

    test('kTranslationLanguages exposes universal pairs', () {
      final codes = kTranslationLanguages.map((l) => l.code).toSet();
      expect(codes, containsAll(['en', 'de', 'fa', 'hi', 'es', 'fr']));
    });
  });

  group('TranslationResult', () {
    const result = TranslationResult(
      word: 'Apfel',
      source: 'de',
      target: 'fa',
      translation: 'سیب',
      alternates: ['سیب (میوه)'],
      partOfSpeech: 'noun',
      gender: 'der',
      definition: 'میوه درخت سیب',
      example: 'Der Apfel ist rot.',
      exampleTranslation: 'سیب قرمز است.',
      fromCache: true,
      cachedAt: null,
    );

    test('isRtl follows the target language', () {
      expect(result.isRtl, isTrue);
      expect(result.targetLanguage?.code, 'fa');
      expect(result.sourceLanguage?.code, 'de');
    });

    test('glossLine combines gender and part of speech', () {
      expect(result.glossLine, 'der · noun');
    });

    test('JSON round-trip preserves every field', () {
      final decoded = TranslationResult.fromJson(result.toJson());
      expect(decoded.word, 'Apfel');
      expect(decoded.translation, 'سیب');
      expect(decoded.alternates, ['سیب (میوه)']);
      expect(decoded.partOfSpeech, 'noun');
      expect(decoded.gender, 'der');
      expect(decoded.definition, 'میوه درخت سیب');
      expect(decoded.example, 'Der Apfel ist rot.');
      expect(decoded.exampleTranslation, 'سیب قرمز است.');
      expect(decoded.fromCache, isTrue);
    });

    test('copyWith overrides only the given fields', () {
      final updated = result.copyWith(fromCache: false);
      expect(updated.fromCache, isFalse);
      expect(updated.translation, 'سیب');
      expect(updated.word, 'Apfel');
    });

    test('isEmpty when the gloss is blank', () {
      const empty = TranslationResult(
        word: 'x',
        source: 'en',
        target: 'fa',
        translation: ' ',
      );
      expect(empty.isEmpty, isTrue);
    });
  });
}
