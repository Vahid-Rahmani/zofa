import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/services/gamification_catalog.dart';
import 'package:zova/features/gamification/badges_screen.dart';
import 'package:zova/features/gamification/hearts_bar.dart';
import 'package:zova/features/gamification/league_screen.dart';
import 'package:zova/features/gamification/quests_screen.dart';

void main() {
  final clock = DateTime(2026, 8, 3, 9); // a Monday

  Future<AppController> buildController() async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(
      language: LanguageController(),
      now: () => clock,
    );
    await controller.bootstrap();
    await controller.signUp(email: 'ui@example.com', password: 'secret123');
    return controller;
  }

  Widget wrap(AppController controller, Widget child) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: controller)],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('quests screen shows goals, complete goals and claim rewards',
      (tester) async {
    final controller = await buildController();
    await controller.completeLesson(
      lessonId: 'lesson_a1_greetings',
      xpEarned: 30,
      wordsEarned: 5,
    );

    await tester.pumpWidget(wrap(controller, const QuestsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Daily Quests'), findsOneWidget);
    expect(find.text('Earn 30 XP'), findsOneWidget);
    expect(find.text('Learn 5 new words'), findsOneWidget);
    expect(find.text('Review 10 cards'), findsOneWidget);

    final xpQuest = GamificationCatalog.quests.first;
    await tester.tap(find.text('+${xpQuest.xpReward} XP').first);
    await tester.pumpAndSettle();

    expect(find.text('Reward claimed ✓'), findsOneWidget);
  });

  testWidgets('league screen shows tier, leaderboard and daily gift',
      (tester) async {
    final controller = await buildController();
    await tester.pumpWidget(wrap(controller, const LeagueScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Bronze league'), findsOneWidget);
    expect(find.text('You are #', findRichText: true), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Power-ups'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Power-ups'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Daily gift'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Daily gift'), findsOneWidget);

    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();

    expect(find.text('Claimed'), findsOneWidget);
    expect(find.text('×1'), findsWidgets,
        reason: 'gift grants a boost and a freeze');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('badges screen lists the full catalog', (tester) async {
    final controller = await buildController();
    await tester.pumpWidget(wrap(controller, const BadgesScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('0 of ${GamificationCatalog.badges.length} badges earned'),
      findsOneWidget,
    );
    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text('Day Tripper'), findsOneWidget);
  });

  testWidgets('hearts bar reflects hearts and refill', (tester) async {
    final controller = await buildController();
    await tester.pumpWidget(
      wrap(
        controller,
        const Scaffold(body: Center(child: HeartsBar(showCount: true))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5/5'), findsOneWidget);

    await controller.consumeHeart();
    await tester.pumpAndSettle();

    expect(find.text('4/5'), findsOneWidget);
    expect(find.textContaining('refills in'), findsOneWidget);
  });
}
