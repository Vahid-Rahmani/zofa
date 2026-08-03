import 'dart:math';

import '../models/gamification_state.dart';
import '../models/user_progress.dart';

/// A single daily quest with a fixed target and progress read from the
/// learner's [GamificationState] daily counters.
class DailyQuest {
  const DailyQuest({
    required this.id,
    required this.title,
    required this.icon,
    required this.target,
    required this.xpReward,
  });

  final String id;
  final String title;
  final String icon;
  final int target;
  final int xpReward;

  int progressOf(GamificationState g) {
    switch (id) {
      case 'xp':
        return g.dailyXp;
      case 'words':
        return g.dailyWords;
      case 'reviews':
        return g.dailyReviews;
      default:
        return 0;
    }
  }

  bool isComplete(GamificationState g) => progressOf(g) >= target;
}

/// A badge the learner can unlock, evaluated against overall progress.
class Badge {
  const Badge({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    required this.isEarned,
  });

  final String id;
  final String title;
  final String icon;
  final String description;
  final bool Function(UserProgress progress) isEarned;
}

/// The Duolingo-style gamification catalog: daily quests, badges and weekly
/// league tiers. Purely functional — no state, safe to call from any layer.
abstract final class GamificationCatalog {
  /// The three daily quests. Targets mirror Duolingo's "daily goals".
  static const List<DailyQuest> quests = [
    DailyQuest(
      id: 'xp',
      title: 'Earn 30 XP',
      icon: '⚡',
      target: 30,
      xpReward: 10,
    ),
    DailyQuest(
      id: 'words',
      title: 'Learn 5 new words',
      icon: '📚',
      target: 5,
      xpReward: 10,
    ),
    DailyQuest(
      id: 'reviews',
      title: 'Review 10 cards',
      icon: '🔄',
      target: 10,
      xpReward: 10,
    ),
  ];

  static final List<Badge> badges = [
    Badge(
      id: 'first_lesson',
      title: 'First Steps',
      icon: '🌱',
      description: 'Complete your first lesson.',
      isEarned: (p) => p.stars >= 1,
    ),
    Badge(
      id: 'ten_lessons',
      title: 'Getting Started',
      icon: '📘',
      description: 'Complete 10 lessons.',
      isEarned: (p) => p.stars >= 10,
    ),
    Badge(
      id: 'fifty_lessons',
      title: 'On a Roll',
      icon: '🚀',
      description: 'Complete 50 lessons.',
      isEarned: (p) => p.stars >= 50,
    ),
    Badge(
      id: 'streak_three',
      title: 'Day Tripper',
      icon: '🔥',
      description: 'Reach a 3-day streak.',
      isEarned: (p) => p.streakDays >= 3,
    ),
    Badge(
      id: 'streak_seven',
      title: 'Week Warrior',
      icon: '💪',
      description: 'Reach a 7-day streak.',
      isEarned: (p) => p.streakDays >= 7,
    ),
    Badge(
      id: 'streak_thirty',
      title: 'Iron Will',
      icon: '⚔️',
      description: 'Reach a 30-day streak.',
      isEarned: (p) => p.streakDays >= 30,
    ),
    Badge(
      id: 'words_twenty',
      title: 'Vocab Builder',
      icon: '📚',
      description: 'Learn 20 words.',
      isEarned: (p) => p.wordsLearned >= 20,
    ),
    Badge(
      id: 'words_hundred',
      title: 'Centurion',
      icon: '🏆',
      description: 'Learn 100 words.',
      isEarned: (p) => p.wordsLearned >= 100,
    ),
    Badge(
      id: 'xp_five_hundred',
      title: 'High Flyer',
      icon: '🎯',
      description: 'Earn 500 XP.',
      isEarned: (p) => p.xp >= 500,
    ),
    Badge(
      id: 'xp_two_thousand',
      title: 'XP Machine',
      icon: '🤖',
      description: 'Earn 2000 XP.',
      isEarned: (p) => p.xp >= 2000,
    ),
    Badge(
      id: 'saved_ten',
      title: 'Collector',
      icon: '💎',
      description: 'Bookmark 10 words.',
      isEarned: (p) => _anyLangCount(p, p.savedWordsFor) >= 10,
    ),
    Badge(
      id: 'master_box',
      title: 'Master Box',
      icon: '🧠',
      description: 'Get a word to box 5.',
      isEarned: (p) => p.learning.values.any((s) => s.box >= 5),
    ),
  ];

  static int _anyLangCount(
    UserProgress p,
    List<String> Function(String code) selector,
  ) {
    final codes = ['en', 'de', 'es', 'fr'];
    return codes.fold<int>(0, (sum, code) => sum + selector(code).length);
  }

  /// Badge ids that are earned for [progress] but not yet granted to
  /// [gamification].
  static List<Badge> newlyEarned(UserProgress progress, GamificationState g) {
    final granted = g.earnedBadges.toSet();
    return [
      for (final badge in badges)
        if (!granted.contains(badge.id) && badge.isEarned(progress)) badge,
    ];
  }

  /// All badges, earned or not, so the UI can show locked slots.
  static List<Badge> allBadges() => badges;

  // -------------------------------------------------------------------------
  // Weekly league
  // -------------------------------------------------------------------------

  static const List<String> tiers = [
    'Bronze',
    'Silver',
    'Gold',
    'Sapphire',
    'Ruby',
    'Diamond',
  ];

  static const List<int> tierThresholds = [0, 150, 400, 800, 1500, 2500];

  /// The tier name for [xp] earned in the current league week.
  static String tierFor(int xp) {
    var tier = tiers.first;
    for (var i = tiers.length - 1; i >= 0; i--) {
      if (xp >= tierThresholds[i]) {
        tier = tiers[i];
        break;
      }
    }
    return tier;
  }

  /// Position (1-based) of the learner's [xp] against [competitors] XPs.
  static int positionInLeague(int xp, List<int> competitorXps) {
    final scores = [...competitorXps, xp]..sort((a, b) => b.compareTo(a));
    return scores.indexOf(xp) + 1;
  }
}

/// A deterministic weekly league of bot competitors so the leaderboard feels
/// alive without a backend. Competitor names and scores are seeded from the
/// league week so the standings are stable within a week and change weekly.
class LeagueTable {
  const LeagueTable({
    required this.weekKey,
    required this.tier,
    required this.playerXp,
    required this.entries,
  });

  final String weekKey;
  final String tier;
  final int playerXp;

  /// Rows sorted by XP descending; the player's row is flagged with `isPlayer`.
  final List<LeagueEntry> entries;

  int get playerPosition {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].isPlayer) return i + 1;
    }
    return entries.length;
  }

  static const List<String> _names = [
    'Lena', 'Tom', 'Sara', 'Max', 'Ava', 'Leo', 'Nina', 'Omar',
    'Emma', 'Yusuf', 'Mia', 'Ben', 'Zoe', 'Ali', 'Ivy', 'Nico',
  ];

  static LeagueTable simulate({
    required String weekKey,
    required int playerXp,
    required String playerName,
  }) {
    final tier = GamificationCatalog.tierFor(playerXp);
    final rand = Random(weekKey.hashCode);
    final tierIndex = GamificationCatalog.tiers.indexOf(tier);
    final base = GamificationCatalog.tierThresholds[tierIndex];
    final ceiling = base + 300 + tierIndex * 150;

    final competitorXps = <int>[];
    for (var i = 0; i < 7; i++) {
      competitorXps.add(base + rand.nextInt(ceiling - base + 1));
    }

    final rows = <LeagueEntry>[];
    final scores = <int, List<String>>{};
    for (var i = 0; i < _names.length; i++) {
      final name = _names[(i + weekKey.hashCode) % _names.length];
      if (i < competitorXps.length) {
        scores.putIfAbsent(competitorXps[i], () => []).add(name);
      }
    }
    scores.putIfAbsent(playerXp, () => []).add(playerName);

    final allScores = scores.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final score in allScores) {
      for (final name in scores[score]!) {
        rows.add(
          LeagueEntry(name: name, xp: score, isPlayer: name == playerName),
        );
      }
    }

    return LeagueTable(
      weekKey: weekKey,
      tier: tier,
      playerXp: playerXp,
      entries: rows,
    );
  }
}

class LeagueEntry {
  const LeagueEntry({required this.name, required this.xp, required this.isPlayer});

  final String name;
  final int xp;
  final bool isPlayer;
}
