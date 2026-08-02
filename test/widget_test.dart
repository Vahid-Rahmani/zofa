import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/app.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/features/splash/splash_screen.dart';

void main() {
  testWidgets('splash shows the zova brand', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('zova'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('app boots into onboarding when never onboarded', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppController(),
        child: const ZovaApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Learn a language you love'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
