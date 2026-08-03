import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zova/core/state/app_controller.dart';
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

/// Fake backend that "translates" into Persian by prefixing `FA:` — enough to
/// assert the live glosses the screen renders for each form and example.
class EchoBackend implements TranslationBackend {
  EchoBackend({this.fail = false});

  bool fail;

  @override
  Future<TranslationResult?> lookup(TranslationRequest request) async {
    if (fail) throw Exception('network down');
    return TranslationResult(
      word: request.word,
      source: request.source,
      target: request.target,
      translation: 'FA:${request.word}',
    );
  }
}

void _seedGrammar() {
  EnglishGrammar.seedAsset(
    EnglishGrammar.posAssetPath,
    jsonEncode({
      'be': 'verb',
      'run': 'verb',
      'school': 'noun',
      'apple': 'noun',
      'good': 'adjective',
    }),
  );
  EnglishGrammar.seedAsset(
    EnglishGrammar.verbsAssetPath,
    jsonEncode({
      'be': {'past': 'was/were', 'participle': 'been'},
      'run': {'past': 'ran', 'participle': 'run'},
    }),
  );
}

void _seedFrequency() {
  // A1 band = ranks 1-1000; place recognizable words at the top.
  final words = List<String>.generate(1000, (i) => 'f${i + 1}');
  words[0] = 'you';
  words[2] = 'the';
  words[5] = 'be';
  EnglishFrequencyList.seedAsset(
    EnglishFrequencyList.assetPath,
    jsonEncode(words),
  );
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppController()),
      ChangeNotifierProvider(
        create: (_) => LanguageController(initial: const LanguageSettings()),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUpAll(() {
    _seedGrammar();
    _seedFrequency();
  });

  late EchoBackend backend;

  setUp(() {
    backend = EchoBackend();
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

  testWidgets('shows the live translation, part of speech and save buttons',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const WordStudyScreen(word: 'school', level: 'A2', rank: 1500),
    ));
    await tester.pumpAndSettle();

    expect(find.text('school'), findsNWidgets(2)); // app bar + header
    expect(find.text('noun'), findsOneWidget);
    expect(find.text('FA:school'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('#1500'), findsOneWidget);
    expect(find.text('Examples'), findsOneWidget);
    expect(find.text('“I see the school.”'), findsOneWidget);
    expect(find.text('FA:I see the school.'), findsOneWidget);
    expect(find.text('“The school is here.”'), findsOneWidget);
    expect(find.text('Verb forms'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Leitner'), findsOneWidget);
  });

  testWidgets('shows the Active/Passive Present/Past/Future conjugation table '
      'and translated forms for a verb', (tester) async {
    await tester.pumpWidget(_wrap(
      const WordStudyScreen(word: 'run', level: 'A1', rank: 7),
    ));
    await tester.pumpAndSettle();

    expect(find.text('verb'), findsOneWidget);
    expect(find.text('Verb forms'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Passive'), findsOneWidget);
    for (final tense in ['Present', 'Past', 'Future']) {
      expect(find.text(tense), findsOneWidget);
    }

    // Active forms in English, each with a live-translated gloss.
    expect(find.text('ran'), findsOneWidget);
    expect(find.text('will run'), findsOneWidget);
    expect(find.text('FA:ran'), findsOneWidget);
    expect(find.text('FA:will run'), findsOneWidget);

    // Passive forms and glosses.
    expect(find.text('am/is/are run'), findsOneWidget);
    expect(find.text('was/were run'), findsOneWidget);
    expect(find.text('will be run'), findsOneWidget);
    expect(find.text('FA:am/is/are run'), findsOneWidget);

    // Example sentences derived from the verb's base form (below the fold).
    await tester.scrollUntilVisible(
      find.text('“I want to run.”'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('“I want to run.”'), findsOneWidget);
    expect(find.text('FA:I want to run.'), findsOneWidget);
    expect(find.text('“We will run tomorrow.”'), findsOneWidget);
  });

  testWidgets('shows an error with retry when the lookup fails offline',
      (tester) async {
    backend.fail = true;
    await tester.pumpWidget(_wrap(
      const WordStudyScreen(word: 'run', level: 'A1'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn’t translate"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    backend.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    // Main translation card + the "present active" verb form both read FA:run.
    expect(find.text('FA:run'), findsNWidgets(2));
  });

  testWidgets('tapping a word in a theme opens its study screen',
      (tester) async {
    await tester.pumpWidget(_wrap(const LevelWordsScreen(level: 'A1')));
    await tester.pumpAndSettle();

    expect(find.byType(WordStudyScreen), findsNothing);
    await tester.tap(find.text('Verbs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('be'));
    await tester.pumpAndSettle();

    expect(find.byType(WordStudyScreen), findsOneWidget);
    expect(find.text('Verb forms'), findsOneWidget);
    // Main translation card + the "present active" verb form both read FA:be.
    expect(find.text('FA:be'), findsNWidgets(2));
  });
}
