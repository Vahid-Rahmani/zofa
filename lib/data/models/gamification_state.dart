/// Serializable gamification state carried inside [UserProgress].
///
/// Holds everything Duolingo-style mechanics need that the plain progress
/// counters don't: hearts with a timed refill, owned consumable items (XP
/// boosts, streak freezes), the active boost window, today's quest counters
/// and the weekly league envelope.
///
/// Every field has a safe default so old saved progress loads cleanly.
class GamificationState {
  const GamificationState({
    this.hearts = maxHearts,
    this.heartsUpdatedAt,
    this.ownedItems = const {},
    this.boostExpiresAt,
    this.questDate,
    this.dailyXp = 0,
    this.dailyWords = 0,
    this.dailyReviews = 0,
    this.claimedQuests = const [],
    this.dailyGiftClaimed = false,
    this.earnedBadges = const [],
    this.leagueWeek,
    this.leagueXp = 0,
    this.leagueTier = 'Bronze',
  });

  /// Maximum hearts a learner can hold.
  static const int maxHearts = 5;

  /// How long one heart takes to regenerate.
  static const Duration heartRegenInterval = Duration(minutes: 30);

  /// Owning item id for a time-limited double-XP boost.
  static const String itemXpBoost = 'xp_boost';

  /// Owning item id for a streak-protection freeze.
  static const String itemStreakFreeze = 'streak_freeze';

  /// Current hearts at rest (before time-based refill is applied).
  final int hearts;

  /// When the hearts count last changed (drives the timed refill).
  final DateTime? heartsUpdatedAt;

  /// item id -> quantity owned (see [itemXpBoost], [itemStreakFreeze]).
  final Map<String, int> ownedItems;

  /// While now is before this stamp, earned XP is doubled.
  final DateTime? boostExpiresAt;

  /// Local day key (`yyyy-MM-dd`) the daily counters belong to.
  final String? questDate;

  /// XP earned today (quest progress).
  final int dailyXp;

  /// Words learned today (quest progress).
  final int dailyWords;

  /// Card reviews answered today (quest progress).
  final int dailyReviews;

  /// Quest ids whose reward has already been claimed today.
  final List<String> claimedQuests;

  /// Whether today's free daily gift (a boost + a streak freeze) was claimed.
  final bool dailyGiftClaimed;

  /// Badge ids the learner has unlocked (see the gamification catalog).
  final List<String> earnedBadges;

  /// Local day key of the Monday that started the current league week.
  final String? leagueWeek;

  /// XP earned inside the current league week.
  final int leagueXp;

  /// League tier name (Bronze..Diamond) derived from league XP.
  final String leagueTier;

  // -------------------------------------------------------------------------
  // Derived views
  // -------------------------------------------------------------------------

  /// Local day key for [date] (`yyyy-MM-dd`).
  static String dayKey(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Whether a boost is active at [now].
  bool boostActiveAt(DateTime now) =>
      boostExpiresAt != null && now.isBefore(boostExpiresAt!);

  bool ownsItem(String id) => (ownedItems[id] ?? 0) > 0;

  /// Hearts after applying the time-based refill up to [maxHearts].
  int heartsAt(DateTime now) {
    if (hearts >= maxHearts) return hearts;
    final updatedAt = heartsUpdatedAt;
    if (updatedAt == null) return hearts;
    final regen = now.difference(updatedAt).inMinutes ~/
        heartRegenInterval.inMinutes;
    if (regen <= 0) return hearts;
    return (hearts + regen).clamp(0, maxHearts);
  }

  /// Whether a review/lesson may consume another heart at [now].
  bool canAffordHeart(DateTime now) => heartsAt(now) > 0;

  // -------------------------------------------------------------------------
  // Mutations (all immutable)
  // -------------------------------------------------------------------------

  /// Consumes one heart after applying the timed refill; never goes below 0.
  GamificationState consumeHeart(DateTime now) {
    final refilled = refillHearts(now);
    final next = (refilled.hearts - 1).clamp(0, maxHearts);
    return refilled.copyWith(hearts: next, heartsUpdatedAt: now);
  }

  /// Advances hearts by the elapsed refill, if any.
  GamificationState refillHearts(DateTime now) {
    if (hearts >= maxHearts) return this;
    final updatedAt = heartsUpdatedAt;
    if (updatedAt == null) return this;
    final regen = now.difference(updatedAt).inMinutes ~/
        heartRegenInterval.inMinutes;
    if (regen <= 0) return this;
    final next = (hearts + regen).clamp(0, maxHearts);
    return copyWith(
      hearts: next,
      heartsUpdatedAt:
          updatedAt.add(Duration(minutes: regen * heartRegenInterval.inMinutes)),
    );
  }

  GamificationState addItem(String id, [int quantity = 1]) => copyWith(
        ownedItems: {...ownedItems, id: (ownedItems[id] ?? 0) + quantity},
      );

  GamificationState spendItem(String id) {
    final current = ownedItems[id] ?? 0;
    if (current <= 0) return this;
    final next = {...ownedItems};
    if (current == 1) {
      next.remove(id);
    } else {
      next[id] = current - 1;
    }
    return copyWith(ownedItems: next);
  }

  /// Activates a double-XP window of [duration] at [now] (consumes the item).
  GamificationState activateBoost(DateTime now,
          {Duration duration = const Duration(minutes: 15)}) =>
      spendItem(itemXpBoost).copyWith(
        boostExpiresAt: now.add(duration),
      );

  /// Rolls the daily counters over when [now] is a different day than the
  /// stored [questDate].
  GamificationState rollDaily(DateTime now) {
    final key = dayKey(now);
    if (questDate == key) return this;
    return copyWith(
      questDate: key,
      dailyXp: 0,
      dailyWords: 0,
      dailyReviews: 0,
      claimedQuests: const [],
      dailyGiftClaimed: false,
    );
  }

  /// Starts a fresh league week when [now] is not inside [leagueWeek].
  GamificationState rollLeagueWeek(DateTime now) {
    final monday = _mondayOf(now);
    final key = dayKey(monday);
    if (leagueWeek == key) return this;
    return copyWith(
      leagueWeek: key,
      leagueXp: 0,
      leagueTier: 'Bronze',
    );
  }

  static DateTime _mondayOf(DateTime date) {
    final weekday = date.weekday; // 1 = Monday .. 7 = Sunday
    final delta = weekday - 1;
    return DateTime(date.year, date.month, date.day).subtract(
      Duration(days: delta),
    );
  }

  GamificationState addDaily({int xp = 0, int words = 0, int reviews = 0}) =>
      copyWith(
        dailyXp: dailyXp + xp,
        dailyWords: dailyWords + words,
        dailyReviews: dailyReviews + reviews,
      );

  GamificationState addLeagueXp(int amount) => copyWith(leagueXp: leagueXp + amount);

  GamificationState withTier(String tier) => copyWith(leagueTier: tier);

  GamificationState claimQuest(String questId) => copyWith(
        claimedQuests: {...claimedQuests, questId}.toList(),
      );

  /// Marks today's daily gift as claimed.
  GamificationState claimDailyGift() => copyWith(dailyGiftClaimed: true);

  GamificationState withBadge(String badgeId) => copyWith(
        earnedBadges: {...earnedBadges, badgeId}.toList(),
      );

  GamificationState copyWith({
    int? hearts,
    DateTime? heartsUpdatedAt,
    Map<String, int>? ownedItems,
    DateTime? boostExpiresAt,
    String? questDate,
    int? dailyXp,
    int? dailyWords,
    int? dailyReviews,
    List<String>? claimedQuests,
    bool? dailyGiftClaimed,
    List<String>? earnedBadges,
    String? leagueWeek,
    int? leagueXp,
    String? leagueTier,
  }) {
    return GamificationState(
      hearts: hearts ?? this.hearts,
      heartsUpdatedAt: heartsUpdatedAt ?? this.heartsUpdatedAt,
      ownedItems: ownedItems ?? this.ownedItems,
      boostExpiresAt: boostExpiresAt ?? this.boostExpiresAt,
      questDate: questDate ?? this.questDate,
      dailyXp: dailyXp ?? this.dailyXp,
      dailyWords: dailyWords ?? this.dailyWords,
      dailyReviews: dailyReviews ?? this.dailyReviews,
      claimedQuests: claimedQuests ?? this.claimedQuests,
      dailyGiftClaimed: dailyGiftClaimed ?? this.dailyGiftClaimed,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      leagueWeek: leagueWeek ?? this.leagueWeek,
      leagueXp: leagueXp ?? this.leagueXp,
      leagueTier: leagueTier ?? this.leagueTier,
    );
  }

  // -------------------------------------------------------------------------
  // Serialisation
  // -------------------------------------------------------------------------

  factory GamificationState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GamificationState();
    return GamificationState(
      hearts: (json['hearts'] as num?)?.toInt() ?? maxHearts,
      heartsUpdatedAt: _parse(json['hearts_updated_at']),
      ownedItems: {
        for (final e in (json['owned_items'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: (e.value as num).toInt(),
      },
      boostExpiresAt: _parse(json['boost_expires_at']),
      questDate: json['quest_date'] as String?,
      dailyXp: (json['daily_xp'] as num?)?.toInt() ?? 0,
      dailyWords: (json['daily_words'] as num?)?.toInt() ?? 0,
      dailyReviews: (json['daily_reviews'] as num?)?.toInt() ?? 0,
      claimedQuests:
          (json['claimed_quests'] as List<dynamic>? ?? const []).cast<String>(),
      dailyGiftClaimed: (json['daily_gift_claimed'] as bool?) ?? false,
      earnedBadges:
          (json['earned_badges'] as List<dynamic>? ?? const []).cast<String>(),
      leagueWeek: json['league_week'] as String?,
      leagueXp: (json['league_xp'] as num?)?.toInt() ?? 0,
      leagueTier: json['league_tier'] as String? ?? 'Bronze',
    );
  }

  static DateTime? _parse(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw);

  Map<String, dynamic> toJson() => {
        'hearts': hearts,
        'hearts_updated_at': heartsUpdatedAt?.toIso8601String(),
        'owned_items': ownedItems,
        'boost_expires_at': boostExpiresAt?.toIso8601String(),
        'quest_date': questDate,
        'daily_xp': dailyXp,
        'daily_words': dailyWords,
        'daily_reviews': dailyReviews,
        'claimed_quests': claimedQuests,
        'daily_gift_claimed': dailyGiftClaimed,
        'earned_badges': earnedBadges,
        'league_week': leagueWeek,
        'league_xp': leagueXp,
        'league_tier': leagueTier,
      };
}
