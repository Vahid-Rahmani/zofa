import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/app.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Serve the bundled dictionaries synchronously so the widget tree has no
    // pending asset I/O (real I/O cannot complete under the fake async clock).
    DictionaryService.seedAsset(
      'assets/dictionary/english.json',
      await File('assets/dictionary/english.json').readAsString(),
    );
    DictionaryService.seedAsset(
      'assets/dictionary/german.json',
      await File('assets/dictionary/german.json').readAsString(),
    );
  });

  testWidgets('full flow: onboarding -> register -> home', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppController()),
          ChangeNotifierProvider(create: (_) => LanguageController()),
        ],
        child: const ZovaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Initial language onboarding: native + learning languages.
    expect(find.text('What’s your native language?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to learn?'), findsOneWidget);
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();

    // Auth gate -> create account.
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name (optional)'), 'Alex');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'alex@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'), 'secret123');

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // Signed in -> home shell with the Home dashboard tab.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Dictionary'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Vocabulary'), findsOneWidget);
    expect(find.text('Listening & Reading'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);

    // The Quick access grid sits below the fold; scroll it into view.
    await tester.scrollUntilVisible(
      find.text('Leitner Box'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Leitner Box'), findsOneWidget);
    expect(find.text('My Words'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
  });
}
