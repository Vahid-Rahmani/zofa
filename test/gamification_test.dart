import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/models/app_user.dart';
import 'package:zova/data/models/gamification_state.dart';
import 'package:zova/data/models/user_progress.dart';
import 'package:zova/data/repositories/progress_repository.dart';
import 'package:zova/data/services/gamification_catalog.dart';
import 'package:zova/data/services/spaced_repetition.dart';

void main() {
  group('GamificationState', () {
    final monday = DateTime(2026, 8, 3, 9); // a Monday

    test('starts at full hearts', () {
      expect(const GamificationState().hearts, GamificationState.maxHearts);
      expect(const GamificationState().heartsAt(monday),
          GamificationState.maxHearts);
    });

    test('consuming hearts never goes below zero', () {
      var g = const GamificationState().consumeHeart(monday);
      expect(g.hearts, 4);
      g = g.consumeHeart(monday.add(const Duration(minutes: 5)));
      g = g.consumeHeart(monday.add(const Duration(minutes: 10)));
      g = g.consumeHeart(monday.add(const Duration(minutes: 15)));
      g = g.consumeHeart(monday.add(const Duration(minutes: 20)));
      g = g.consumeHeart(monday.add(const Duration(minutes: 25)));
      expect(g.hearts, 0);
    });

    test('hearts refill one per 30 minutes up to max', () {
      final low = GamificationState(hearts: 1, heartsUpdatedAt: monday);
      expect(low.heartsAt(monday.add(const Duration(minutes: 29))), 1);
      expect(low.heartsAt(monday.add(const Duration(minutes: 30))), 2);
      expect(low.heartsAt(monday.add(const Duration(minutes: 150))), 5);
      expect(low.heartsAt(monday.add(const Duration(days: 1))), 5);
    });

    test('boost activates from an owned item and expires', () {
      var g = const GamificationState().addItem(GamificationState.itemXpBoost);
      expect(g.boostActiveAt(monday), isFalse);
      g = g.activateBoost(monday);
      expect(g.ownsItem(GamificationState.itemXpBoost), isFalse);
      expect(g.boostActiveAt(monday), isTrue);
      expect(
        g.boostActiveAt(monday.add(const Duration(minutes: 16))),
        isFalse,
      );
    });

    test('rollDaily resets quest counters on a new day', () {
      var g = const GamificationState().rollDaily(monday).addDaily(xp: 10, words: 2);
      expect(g.questDate, GamificationState.dayKey(monday));
      g = g.rollDaily(monday); // same day keeps counters
      expect(g.dailyXp, 10);
      g = g.rollDaily(monday.add(const Duration(days: 1)));
      expect(g.dailyXp, 0);
      expect(g.claimedQuests, isEmpty);
    });

    test('rollLeagueWeek starts a fresh week on the following Monday', () {
      var g = const GamificationState().addLeagueXp(500);
      g = g.rollLeagueWeek(monday);
      expect(g.leagueWeek, GamificationState.dayKey(monday));
      g = g.rollLeagueWeek(monday.add(const Duration(days: 7)));
      expect(g.leagueXp, 0);
      expect(g.leagueTier, 'Bronze');
    });

    test('round-trips through JSON', () {
      final g = GamificationState(hearts: 3, heartsUpdatedAt: monday)
          .addItem(GamificationState.itemStreakFreeze)
          .withBadge('first_lesson')
          .withTier('Gold');
      final restored = GamificationState.fromJson(g.toJson());
      expect(restored.hearts, 3);
      expect(restored.heartsUpdatedAt, monday);
      expect(restored.ownsItem(GamificationState.itemStreakFreeze), isTrue);
      expect(restored.earnedBadges, ['first_lesson']);
      expect(restored.leagueTier, 'Gold');
    });

    test('fromJson with null falls back to defaults', () {
      expect(GamificationState.fromJson(null).hearts, GamificationState.maxHearts);
    });
  });

  group('GamificationCatalog', () {
    test('tierFor climbs the ladder at the thresholds', () {
      expect(GamificationCatalog.tierFor(0), 'Bronze');
      expect(GamificationCatalog.tierFor(149), 'Bronze');
      expect(GamificationCatalog.tierFor(150), 'Silver');
      expect(GamificationCatalog.tierFor(400), 'Gold');
      expect(GamificationCatalog.tierFor(800), 'Sapphire');
      expect(GamificationCatalog.tierFor(1500), 'Ruby');
      expect(GamificationCatalog.tierFor(2500), 'Diamond');
      expect(GamificationCatalog.tierFor(999999), 'Diamond');
    });

    test('positionInLeague ranks the player among competitors', () {
      expect(GamificationCatalog.positionInLeague(500, [100, 200, 300]), 1);
      expect(GamificationCatalog.positionInLeague(100, [200, 300]), 3);
    });

    test('newlyEarned only lists unearned badges that now qualify', () {
      final progress = UserProgress().copyWith(streakDays: 3);
      const g = GamificationState();
      final earned = GamificationCatalog.newlyEarned(progress, g).map((b) => b.id);
      expect(earned, contains('streak_three'));
      expect(earned, isNot(contains('first_lesson')));
      expect(earned, isNot(contains('streak_seven')));
    });

    test('LeagueTable is deterministic within a week and contains the player', () {
      final a = LeagueTable.simulate(
        weekKey: '2026-08-03',
        playerXp: 300,
        playerName: 'You',
      );
      final b = LeagueTable.simulate(
        weekKey: '2026-08-03',
        playerXp: 300,
        playerName: 'You',
      );
      expect(a.entries.map((e) => e.xp), b.entries.map((e) => e.xp));
      expect(a.playerPosition, b.playerPosition);
      expect(a.entries.any((e) => e.isPlayer), isTrue);
      expect(a.tier, 'Silver');
    });
  });

  group('AppController gamification wiring', () {
    final clock = DateTime(2026, 8, 3, 9);

    Future<AppController> buildController() async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(
        language: LanguageController(),
        scheduler: SpacedRepetitionScheduler(now: () => clock),
        now: () => clock,
      );
      await controller.bootstrap();
      await controller.signUp(email: 'g@example.com', password: 'secret123');
      return controller;
    }

    test('an active boost doubles lesson XP', () async {
      final controller = await buildController();
      await controller.grantItem(GamificationState.itemXpBoost);
      await controller.activateBoost();

      await controller.completeLesson(
        lessonId: 'lesson_a1_greetings',
        xpEarned: 10,
        wordsEarned: 5,
      );

      expect(controller.boostActive, isTrue);
      expect(controller.progress.xp, 20);
      expect(controller.progress.gamification.dailyXp, 20);
      expect(controller.progress.gamification.dailyWords, 5);
      expect(controller.progress.gamification.leagueXp, 20);
    });

    test('completing lessons awards badges', () async {
      final controller = await buildController();
      await controller.completeLesson(
        lessonId: 'lesson_a1_greetings',
        xpEarned: 10,
        wordsEarned: 5,
      );
      expect(controller.gamification.earnedBadges, contains('first_lesson'));
    });

    test('claimQuest grants quest XP once', () async {
      final controller = await buildController();
      await controller.completeLesson(
        lessonId: 'lesson_a1_greetings',
        xpEarned: 30,
        wordsEarned: 5,
      );
      final quest = GamificationCatalog.quests.first;
      final claimed = await controller.claimQuest(quest.id);
      expect(claimed, isTrue);
      expect(
        controller.progress.gamification.claimedQuests,
        contains(quest.id),
      );
      expect(controller.progress.xp, 30 + quest.xpReward);
      expect(await controller.claimQuest(quest.id), isFalse,
          reason: 'a quest is only claimable once per day');
    });

    test('a failed review consumes a heart; daily reviews increment', () async {
      final controller = await buildController();
      await controller.addToLeitner('Apfel');
      await controller.reviewLeitnerCard('Apfel', knew: false);
      expect(controller.hearts, GamificationState.maxHearts - 1);
      expect(controller.progress.gamification.dailyReviews, 1);
    });

    test('a skipped day resets the streak unless a freeze is owned', () async {
      SharedPreferences.setMockInitialValues({});
      const user = AppUser(id: 'u1', email: 'g@example.com');
      final base = UserProgress()
          .copyWith(streakDays: 5, lastActiveDay: '2026-08-03');

      // Without a freeze the streak resets to 1 after a gap.
      final plain = ProgressRepository(now: () => DateTime(2026, 8, 10, 9));
      final reset = await plain.touchDailyStreak(user, base);
      expect(reset.streakDays, 1);

      // With a freeze owned, the streak survives and the item is consumed.
      final frozen = base.copyWith(
        gamification:
            base.gamification.addItem(GamificationState.itemStreakFreeze),
      );
      final preserved = await ProgressRepository(
        now: () => DateTime(2026, 8, 10, 9),
      ).touchDailyStreak(user, frozen);
      expect(preserved.streakDays, 6);
      expect(preserved.gamification.ownsItem(GamificationState.itemStreakFreeze),
          isFalse);
    });
  });
}
