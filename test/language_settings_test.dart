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
    test('defaults to a Persian speaker learning English', () {
      const settings = LanguageSettings();
      expect(settings.nativeLanguage, 'fa');
      expect(settings.learningLanguage, 'en');
      expect(settings.uiLanguage, AppLanguage.persian);
      expect(settings.translationLanguage, AppLanguage.persian);
      expect(settings.isRtlUi, isTrue);
    });

    test('an English native flips the UI to LTR', () {
      const settings =
          LanguageSettings(nativeLanguage: 'en', learningLanguage: 'de');
      expect(settings.uiLanguage, AppLanguage.english);
      expect(settings.translationLanguage, AppLanguage.english);
      expect(settings.isRtlUi, isFalse);
    });

    test('round-trips through JSON', () {
      const settings =
          LanguageSettings(nativeLanguage: 'de', learningLanguage: 'fa');
      final restored = LanguageSettings.fromJson(settings.toJson());
      expect(restored.nativeLanguage, 'de');
      expect(restored.learningLanguage, 'fa');
      expect(restored.isRtlUi, isFalse);
    });

    test('migrates the legacy ui/translation schema', () {
      final restored = LanguageSettings.fromJson({
        'ui_language': 'en',
        'translation_language': 'fa',
      });
      expect(restored.nativeLanguage, 'fa');
      expect(restored.learningLanguage, 'en');
      expect(restored.isRtlUi, isTrue);
    });

    test('copyWith only overrides the given fields', () {
      const settings = LanguageSettings();
      final next = settings.copyWith(nativeLanguage: 'en');
      expect(next.nativeLanguage, 'en');
      expect(next.learningLanguage, 'en');
    });
  });

  group('LanguageController', () {
    test('bootstrap loads persisted preferences', () async {
      SharedPreferences.setMockInitialValues({
        'zova.language':
            '{"native_language":"de","learning_language":"fa"}',
      });
      final controller = LanguageController();
      await controller.bootstrap();
      expect(controller.settings.nativeLanguage, 'de');
      expect(controller.settings.learningLanguage, 'fa');
      expect(controller.isRtlUi, isFalse);
    });

    test('bootstrap migrates legacy persisted preferences', () async {
      SharedPreferences.setMockInitialValues({
        'zova.language':
            '{"ui_language":"en","translation_language":"fa"}',
      });
      final controller = LanguageController();
      await controller.bootstrap();
      expect(controller.settings.nativeLanguage, 'fa');
      expect(controller.settings.learningLanguage, 'en');
      expect(controller.isRtlUi, isTrue);
    });

    test('setNativeLanguage persists and flips directionality', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = LanguageController();
      await controller.bootstrap();
      expect(controller.isRtlUi, isTrue);

      await controller.setNativeLanguage('en');
      expect(controller.isRtlUi, isFalse);
      expect((await LocalStore.getLanguageSettings()).nativeLanguage, 'en');

      await controller.setLearningLanguage('de');
      expect(controller.settings.learningLanguage, 'de');
      expect((await LocalStore.getLanguageSettings()).learningLanguage, 'de');
    });

    test('setLanguagePair stores both sides at once', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = LanguageController();
      await controller.bootstrap();

      await controller.setLanguagePair(native: 'de', learning: 'es');
      expect(controller.settings.nativeLanguage, 'de');
      expect(controller.settings.learningLanguage, 'es');
      final stored = await LocalStore.getLanguageSettings();
      expect(stored.nativeLanguage, 'de');
      expect(stored.learningLanguage, 'es');
    });
  });

  group('LanguageSettingsScreen', () {
    testWidgets('changing the native language updates the controller',
        (tester) async {
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

      expect(find.text('Native language'), findsOneWidget);
      expect(find.text('Learning language'), findsOneWidget);
      expect(find.text('فارسی'), findsWidgets);

      await tester.ensureVisible(find.text('English').first);
      await tester.tap(find.text('English').first);
      await tester.pumpAndSettle();

      expect(controller.settings.nativeLanguage, 'en');
      expect(controller.isRtlUi, isFalse);
      // The learning side is bumped away so the pair stays distinct.
      expect(controller.settings.learningLanguage, isNot('en'));
    });
  });
}
