import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/core/state/content_translation_controller.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/models/language_settings.dart';
import 'package:zova/data/models/translation_result.dart';
import 'package:zova/data/services/english_frequency.dart';
import 'package:zova/data/services/english_grammar.dart';
import 'package:zova/data/services/translation_backend.dart';
import 'package:zova/data/services/translation_cache.dart';
import 'package:zova/data/services/translation_service.dart';
import 'package:zova/features/vocabulary/level_words_screen.dart';
import 'package:zova/features/vocabulary/word_study_screen.dart';

/// Fake backend that echoes the requested target language: `[tr]:word`. Lets
/// tests assert which language the screens actually translate into.
class TargetEchoBackend implements TranslationBackend {
  TargetEchoBackend({this.fail = false});

  bool fail;
  final List<TranslationRequest> requests = [];

  @override
  Future<TranslationResult?> lookup(TranslationRequest request) async {
    if (fail) throw Exception('network down');
    requests.add(request);
    return TranslationResult(
      word: request.word,
      source: request.source,
      target: request.target,
      translation: '[${request.target}]:${request.word}',
    );
  }
}

void _seedGrammar() {
  EnglishGrammar.seedAsset(
    EnglishGrammar.posAssetPath,
    jsonEncode({'school': 'noun', 'run': 'verb'}),
  );
  EnglishGrammar.seedAsset(
    EnglishGrammar.verbsAssetPath,
    jsonEncode({
      'run': {'past': 'ran', 'participle': 'run'},
    }),
  );
}

void _seedFrequency() {
  EnglishFrequencyList.seedAsset(
    EnglishFrequencyList.assetPath,
    jsonEncode(List<String>.generate(1000, (i) => 'f${i + 1}')),
  );
}

Future<String?> fakeTranslator(String text, String target) async =>
    '[$target] $text';

void main() {
  group('ContentTranslationController', () {
    test('translates into the content language and re-translates on switch',
        () async {
      final controller = ContentTranslationController(
        code: 'tr',
        translator: fakeTranslator,
      );

      expect(controller.code, 'tr');
      expect(controller.tr('Good morning'), 'Good morning',
          reason: 'English while the fetch is pending');

      await controller.translate('Good morning');
      expect(controller.tr('Good morning'), '[tr] Good morning');

      controller.setCode('de');
      expect(controller.tr('Good morning'), 'Good morning',
          reason: 'hot cache cleared after language switch');
      await controller.translate('Good morning');
      expect(controller.tr('Good morning'), '[de] Good morning');
    });

    test('English target is a passthrough', () {
      final controller = ContentTranslationController(code: 'en');
      expect(controller.tr('Good morning'), 'Good morning');
    });

    test('null result keeps the English source', () async {
      final controller = ContentTranslationController(
        code: 'tr',
        translator: (text, target) async => null,
      );
      await controller.translate('Good morning');
      expect(controller.tr('Good morning'), 'Good morning');
    });
  });

  group('WordStudyScreen content language', () {
    setUpAll(() {
      _seedGrammar();
      _seedFrequency();
    });

    late TargetEchoBackend backend;

    setUp(() {
      backend = TargetEchoBackend();
      TranslationService.instance = TranslationService(
        backend: backend,
        cache: MemoryTranslationCache(),
      );
    });

    tearDown(() {
      TranslationService.instance = TranslationService(
        backend: buildDefaultTranslationBackend(),
        cache: MemoryTranslationCache(),
      );
    });

    Future<void> pumpStudy(
      WidgetTester tester, {
      LanguageSettings settings = const LanguageSettings(
        nativeLanguage: 'fa',
        learningLanguage: 'tr',
      ),
    }) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppController()),
            ChangeNotifierProvider(
              create: (_) => LanguageController(initial: settings),
            ),
          ],
          child: const MaterialApp(home: WordStudyScreen(word: 'school')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('translates word and examples into the first language',
        (tester) async {
      await pumpStudy(tester);

      expect(backend.requests, isNotEmpty);
      expect(backend.requests.every((r) => r.target == 'fa'), isTrue,
          reason: 'every lookup must target the first/native language');
      expect(find.text('[fa]:school'), findsOneWidget);
      expect(find.text('[fa]:I see the school.'), findsOneWidget);
    });

    testWidgets('keeps content in the first language when learning English',
        (tester) async {
      await pumpStudy(
        tester,
        settings: const LanguageSettings(
          nativeLanguage: 'fa',
          learningLanguage: 'en',
        ),
      );

      expect(backend.requests, isNotEmpty);
      expect(backend.requests.every((r) => r.target == 'fa'), isTrue,
          reason: 'the first language stays the target regardless of the '
              'second language');
      expect(find.text('[fa]:school'), findsOneWidget);
    });
  });

  group('LevelWordsScreen word list translation', () {
    setUpAll(() {
      _seedGrammar();
      _seedFrequency();
    });

    Future<void> pumpWordList(WidgetTester tester, {String code = 'de'}) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppController()),
            ChangeNotifierProvider(
              create: (_) => LanguageController(
                initial: LanguageSettings(nativeLanguage: code),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => ContentTranslationController(
                code: code,
                translator: fakeTranslator,
              ),
            ),
          ],
          child: const MaterialApp(home: LevelWordsScreen(level: 'A1')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('every word in the list is shown translated into the native language',
        (tester) async {
      await pumpWordList(tester);

      expect(find.textContaining('[de]'), findsWidgets,
          reason: 'the visible word tiles must swap the English source for the '
              'translated word');
      expect(find.text('f1'), findsNothing,
          reason: 'the English source must be replaced by the translation');
    });

    testWidgets('English target keeps the words untranslated', (tester) async {
      await pumpWordList(tester, code: 'en');

      expect(find.textContaining('[en]'), findsNothing);
      expect(find.text('f1'), findsOneWidget);
    });
  });
}
