import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/app.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/services/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('language onboarding persists the chosen pair and unblocks auth',
      (tester) async {
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

    expect(find.text('What’s your native language?'), findsOneWidget);
    expect(find.text('فارسی'), findsWidgets);

    // Pick German as the native language.
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to learn?'), findsOneWidget);
    // The native language is no longer offered as a learning option.
    expect(find.text('Deutsch'), findsNothing);
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();

    // Onboarding done -> auth gate, and the pair is persisted on-device.
    expect(find.text('Welcome back'), findsOneWidget);
    final stored = await LocalStore.getLanguageSettings();
    expect(stored.nativeLanguage, 'de');
    expect(stored.learningLanguage, 'en');
    expect(stored.isRtlUi, isFalse);
  });
}
