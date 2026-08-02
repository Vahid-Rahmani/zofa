import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/models/language_settings.dart';
import 'package:zova/data/services/dictionary_service.dart';
import 'package:zova/features/dictionary/dictionary_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Serve the bundled dictionary synchronously so the widget tree has no
    // pending asset I/O (real I/O cannot complete under the fake async clock).
    DictionaryService.seedAsset(
      'assets/dictionary/english.json',
      await File('assets/dictionary/english.json').readAsString(),
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    LanguageSettings? language,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageController(initial: language),
          ),
        ],
        child: const MaterialApp(home: DictionaryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder levelChip(String level) => find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text(level),
      );

  testWidgets('renders the indexed dictionary with its counts', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Dictionary'), findsOneWidget);
    expect(find.textContaining('420 words'), findsOneWidget);
    expect(find.text('420 results'), findsOneWidget);
    expect(find.text('abroad'), findsWidgets);
  });

  testWidgets('debounced search narrows the results', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('سلام'), findsOneWidget,
        reason: 'the hello entry should surface');
    expect(find.text('abroad'), findsNothing);
  });

  testWidgets('level filter reports the indexed bucket count', (tester) async {
    await pumpScreen(tester);

    await tester.tap(levelChip('A1'));
    await tester.pumpAndSettle();
    expect(find.text('138 results'), findsOneWidget);

    await tester.tap(levelChip('All'));
    await tester.pumpAndSettle();
    expect(find.text('420 results'), findsOneWidget);
  });

  testWidgets('entry cards follow the preferred translation language',
      (tester) async {
    await pumpScreen(
      tester,
      language: const LanguageSettings(translationLanguage: AppLanguage.english),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('hello'), findsWidgets,
        reason: 'with English explanations the gloss should be English');
    expect(find.text('سلام'), findsOneWidget,
        reason: 'the Persian gloss is still shown as the secondary line');
  });
}
