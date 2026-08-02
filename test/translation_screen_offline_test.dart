import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/models/language_settings.dart';
import 'package:zova/data/models/translation_result.dart';
import 'package:zova/data/services/translation_backend.dart';
import 'package:zova/data/services/translation_cache.dart';
import 'package:zova/data/services/translation_service.dart';
import 'package:zova/features/dictionary/dictionary_screen.dart';

class FailingBackend implements TranslationBackend {
  FailingBackend({this.fail = true});

  bool fail;
  final Map<String, TranslationResult> results = {};

  @override
  Future<TranslationResult?> lookup(TranslationRequest request) async {
    if (fail) throw Exception('network down');
    return results['${request.source}|${request.target}|${request.word.trim().toLowerCase()}'];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FailingBackend backend;

  setUp(() {
    backend = FailingBackend();
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
  );

  testWidgets('offline lookups without a cache entry show an error',
      (tester) async {
    await pumpScreen(tester);
    await search(tester, 'hello');
    expect(find.textContaining("Couldn’t translate"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('retry succeeds once connectivity returns', (tester) async {
    await pumpScreen(tester);
    await search(tester, 'hello');
    expect(find.text('Try again'), findsOneWidget);

    backend.fail = false;
    backend.results['en|fa|hello'] = helloFa;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('سلام'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
  });

  testWidgets('cached words still translate while offline', (tester) async {
    backend.fail = false;
    backend.results['en|fa|hello'] = helloFa;
    await pumpScreen(tester);
    await search(tester, 'hello');
    expect(find.text('سلام'), findsOneWidget);

    backend.fail = true;
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    await search(tester, 'hello');

    expect(find.text('سلام'), findsOneWidget);
    expect(find.text('Cached'), findsOneWidget);
    expect(find.textContaining("Couldn’t translate"), findsNothing);
  });
}
