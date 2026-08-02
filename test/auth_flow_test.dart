import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/app.dart';
import 'package:zova/core/state/app_controller.dart';
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
      ChangeNotifierProvider(
        create: (_) => AppController(),
        child: const ZovaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Walk through the three intro pages.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    // Final prefs page -> start learning.
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

    // Signed in -> home shell with the Courses tab.
    expect(find.text('Learn English'), findsOneWidget);
    expect(find.text('Roadmap'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
