import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/models/language_settings.dart';
import 'package:zova/data/models/translation_language.dart';
import 'package:zova/data/models/translation_result.dart';
import 'package:zova/data/services/translation_backend.dart';
import 'package:zova/data/services/translation_cache.dart';
import 'package:zova/data/services/translation_service.dart';
import 'package:zova/features/dictionary/dictionary_screen.dart';

class FakeTranslationBackend implements TranslationBackend {
  final Map<String, TranslationResult> results = {};
  bool fail = false;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<TranslationResult?> lookup(TranslationRequest request) async {
    calls++;
    if (gate != null) await gate!.future;
    if (fail) throw Exception('network down');
    return results['${request.source}|${request.target}|${request.word.trim().toLowerCase()}'];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTranslationBackend backend;
  late TranslationService service;

  setUp(() {
    backend = FakeTranslationBackend();
    service = TranslationService(
      backend: backend,
      cache: MemoryTranslationCache(),
    );
    TranslationService.instance = service;
  });

  tearDown(() {
    TranslationService.instance = TranslationService(
      backend: buildDefaultTranslationBackend(),
      cache: MemoryTranslationCache(),
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                LanguageController(initial: const LanguageSettings()),
          ),
        ],
        child: const MaterialApp(home: DictionaryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String word) async {
    await tester.enterText(find.byType(TextField), word);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  const helloFa = TranslationResult(
    word: 'hello',
    source: 'en',
    target: 'fa',
    translation: 'سلام',
    partOfSpeech: 'noun',
  );

  testWidgets('shows the header, language pickers and idle hint',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Dictionary'), findsOneWidget);
    expect(
      find.byType(DropdownButton<TranslationLanguage>),
      findsNWidgets(2),
    );
    expect(find.text('English (en)'), findsOneWidget);
    expect(find.text('فارسی (fa)'), findsOneWidget);
    expect(find.text('Type any word to translate it.'), findsOneWidget);
  });

  testWidgets('translates a word and shows the result', (tester) async {
    backend.results['en|fa|hello'] = helloFa;
    await pumpScreen(tester);
    await search(tester, 'hello');
    expect(find.text('سلام'), findsOneWidget);
    expect(find.text('noun'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(backend.calls, 1);
  });

  testWidgets('repeat lookups are served from the cache', (tester) async {
    backend.results['en|fa|hello'] = helloFa;
    await pumpScreen(tester);
    await search(tester, 'hello');
    expect(find.text('Live'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    await search(tester, 'hello');

    expect(backend.calls, 1, reason: 'the repeat must not hit the backend');
    expect(find.text('Cached'), findsOneWidget);
    expect(find.text('سلام'), findsOneWidget);
  });

  testWidgets('shows a loading state while the backend is pending',
      (tester) async {
    backend.gate = Completer<void>();
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('Translating…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    backend.gate!.complete();
    backend.gate = null;
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an error with retry and recovers', (tester) async {
    backend.fail = true;
    await pumpScreen(tester);
    await search(tester, 'hello');
    expect(find.textContaining("Couldn’t translate"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    backend.fail = false;
    backend.results['en|fa|hello'] = helloFa;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('سلام'), findsOneWidget);
  });

  testWidgets('changing the source language re-translates', (tester) async {
    backend.results['en|fa|hello'] = helloFa;
    backend.results['de|fa|hello'] = const TranslationResult(
      word: 'hello',
      source: 'de',
      target: 'fa',
      translation: 'Hallo (de)',
    );
    await pumpScreen(tester);
    await search(tester, 'hello');
    expect(find.text('سلام'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<TranslationLanguage>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch (de)').last);
    await tester.pumpAndSettle();

    expect(find.text('Hallo (de)'), findsOneWidget);
    expect(find.text('سلام'), findsNothing);
  });

  testWidgets('swapping languages translates into the new target',
      (tester) async {
    backend.results['en|fa|hello'] = helloFa;
    backend.results['fa|en|hello'] = const TranslationResult(
      word: 'hello',
      source: 'fa',
      target: 'en',
      translation: 'hi',
    );
    await pumpScreen(tester);
    await search(tester, 'hello');
    expect(find.text('سلام'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();
    expect(find.text('hi'), findsOneWidget);
    expect(find.text('سلام'), findsNothing);
  });

  testWidgets('smart lookup flips direction based on the typed script',
      (tester) async {
    backend.results['en|fa|hello'] = helloFa;
    backend.results['fa|en|سلام'] = const TranslationResult(
      word: 'سلام',
      source: 'fa',
      target: 'en',
      translation: 'hello',
    );
    await pumpScreen(tester);

    // LTR text -> learning (English) -> native (Persian).
    await search(tester, 'hello');
    expect(find.text('سلام'), findsOneWidget);

    // RTL text -> native (Persian) -> learning (English).
    await tester.enterText(find.byType(TextField), 'سلام');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsOneWidget);
    // The pickers followed the smart flip: From فارسی, To English.
    expect(find.text('فارسی (fa)'), findsOneWidget);
    expect(find.text('English (en)'), findsOneWidget);
  });
}
