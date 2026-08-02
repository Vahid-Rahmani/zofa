import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/models/language_settings.dart';
import 'package:zova/data/services/local_store.dart';
import 'package:zova/features/settings/language_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLanguage', () {
    test('maps ISO codes to languages, unknown codes default to English', () {
      expect(AppLanguage.fromCode('fa'), AppLanguage.persian);
      expect(AppLanguage.fromCode('fa-IR'), AppLanguage.english);
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode('zz'), AppLanguage.english);
      expect(AppLanguage.fromCode(null), AppLanguage.english);
    });
  });

  group('LanguageSettings', () {
    test('defaults to an English UI with Persian explanations', () {
      const settings = LanguageSettings();
      expect(settings.uiLanguage, AppLanguage.english);
      expect(settings.translationLanguage, AppLanguage.persian);
      expect(settings.isRtlUi, isFalse);
    });

    test('Persian UI flips directionality', () {
      const settings =
          LanguageSettings(uiLanguage: AppLanguage.persian);
      expect(settings.isRtlUi, isTrue);
    });

    test('round-trips through JSON', () {
      const settings = LanguageSettings(
        uiLanguage: AppLanguage.persian,
        translationLanguage: AppLanguage.english,
      );
      final restored = LanguageSettings.fromJson(settings.toJson());
      expect(restored.uiLanguage, AppLanguage.persian);
      expect(restored.translationLanguage, AppLanguage.english);
    });

    test('copyWith only overrides the given fields', () {
      const settings = LanguageSettings();
      final next = settings.copyWith(uiLanguage: AppLanguage.persian);
      expect(next.uiLanguage, AppLanguage.persian);
      expect(next.translationLanguage, AppLanguage.persian);
    });
  });

  group('LanguageController', () {
    test('bootstrap loads persisted preferences', () async {
      SharedPreferences.setMockInitialValues({
        'zova.language':
            '{"ui_language":"fa","translation_language":"en"}',
      });
      final controller = LanguageController();
      await controller.bootstrap();
      expect(controller.settings.uiLanguage, AppLanguage.persian);
      expect(controller.settings.translationLanguage, AppLanguage.english);
      expect(controller.isRtlUi, isTrue);
    });

    test('setUiLanguage persists and flips directionality', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = LanguageController();
      await controller.bootstrap();
      expect(controller.isRtlUi, isFalse);

      await controller.setUiLanguage(AppLanguage.persian);
      expect(controller.isRtlUi, isTrue);
      expect((await LocalStore.getLanguageSettings()).uiLanguage,
          AppLanguage.persian);

      await controller.setTranslationLanguage(AppLanguage.english);
      expect(controller.settings.translationLanguage, AppLanguage.english);
      expect((await LocalStore.getLanguageSettings()).translationLanguage,
          AppLanguage.english);
    });
  });

  group('LanguageSettingsScreen', () {
    testWidgets('selecting a language updates the controller', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = LanguageController();
      await controller.bootstrap();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: LanguageSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interface language'), findsOneWidget);
      expect(find.text('Translations & explanations'), findsOneWidget);
      expect(find.text('فارسی'), findsWidgets);

      await tester.tap(find.text('فارسی').first);
      await tester.pumpAndSettle();

      expect(controller.settings.uiLanguage, AppLanguage.persian);
      expect(controller.isRtlUi, isTrue);
    });
  });
}
