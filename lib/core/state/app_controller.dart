import 'package:flutter/foundation.dart';

import '../../data/models/app_user.dart';
import '../../data/models/gamification_state.dart';
import '../../data/models/learning_state.dart';
import '../../data/models/translation_language.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/models/user_progress.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/services/gamification_catalog.dart';
import '../../data/services/local_store.dart';
import '../../data/services/remote_api.dart';
import '../../data/services/spaced_repetition.dart';
import '../../data/services/stripe_service.dart';
import 'language_controller.dart';

/// Preferences gathered during the initial language onboarding.
class OnboardingPrefs {
  const OnboardingPrefs({
    this.nativeLanguageCode = 'fa',
    this.learningLanguageCode = 'en',
  });

  /// ISO 639-1 code of the learner's native language.
  final String nativeLanguageCode;

  /// ISO 639-1 code of the language being learned.
  final String learningLanguageCode;
}

/// Central application state for the signed-in user and their progress.
///
/// Exposed to the widget tree through [ChangeNotifierProvider] so screens can
/// react to auth and progress changes without prop drilling.
class AppController extends ChangeNotifier {
  AppController({
    AuthRepository? auth,
    ProgressRepository? progress,
    StripeService? stripe,
    SpacedRepetitionScheduler? scheduler,
    LanguageController? language,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _auth = auth ?? AuthRepository(),
        _progress = progress ?? ProgressRepository(now: now ?? DateTime.now),
        _stripe = stripe ?? StripeService.instance,
        _scheduler = scheduler ?? SpacedRepetitionScheduler(),
        _language = language ?? LanguageController();

  final AuthRepository _auth;
  final ProgressRepository _progress;
  final StripeService _stripe;
  final SpacedRepetitionScheduler _scheduler;
  final LanguageController _language;
  final DateTime Function() _now;

  AppUser? _user;
  UserProgress _progressData = UserProgress();
  bool _busy = false;
  bool _onboarded = false;
  bool _booted = false;
  OnboardingPrefs _prefs = const OnboardingPrefs();

  AppUser? get user => _user;
  UserProgress get progress => _progressData;
  bool get busy => _busy;
  bool get booted => _booted;
  bool get isSignedIn => _user != null;
  bool get isSubscriptionActive => _progressData.subscriptionActive;
  bool get isOnboarded => _onboarded;
  OnboardingPrefs get onboardingPrefs => _prefs;

  /// Language preferences (interface + translation/explanation language).
  /// Owned here so the whole app state is reachable from [AppController].
  LanguageController get language => _language;

  /// Restores the session and local progress at app launch.
  Future<void> bootstrap() async {
    _onboarded = await LocalStore.isOnboarded();
    _user = await _auth.currentUser();
    if (_user != null) {
      _progressData = await _progress.loadProgress(_user!);
      _progressData = await _progress.touchDailyStreak(_user!, _progressData);
    }
    _booted = true;
    notifyListeners();
  }

  void setOnboardingPrefs(OnboardingPrefs prefs) {
    _prefs = prefs;
  }

  /// Persists the "onboarding completed" flag on this device.
  Future<void> markOnboarded() async {
    _onboarded = true;
    await LocalStore.setOnboarded(true);
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _guard(() async {
      await _auth.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _reload();
      final prefs = _prefs;
      final user = _user;
      if (user != null) {
        final native = TranslationLanguage.byCode(prefs.nativeLanguageCode);
        final learning = TranslationLanguage.byCode(prefs.learningLanguageCode);
        _user = user.copyWith(
          nativeLanguage: native?.name ?? 'Persian',
          learnedLanguage: learning?.name ?? 'English',
        );
        await _auth.updateProfile(_user!);
      }
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _guard(() async {
      await _auth.signIn(email: email, password: password);
      await _reload();
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _progressData = UserProgress();
    notifyListeners();
  }

  Future<void> updateProfile(AppUser user) async {
    await _auth.updateProfile(user);
    _user = user;
    notifyListeners();
  }

  /// Marks a lesson as finished, awarding XP and words. The lesson is recorded
  /// under the active learning language so German and English progress never
  /// mixes. When an XP boost is active the award is doubled; daily quest and
  /// weekly league counters advance and newly earned badges are granted.
  Future<UserProgress> completeLesson({
    required String lessonId,
    required int xpEarned,
    required int wordsEarned,
  }) async {
    final user = _user;
    if (user == null) return _progressData;
    final now = _now();
    final boostActive = _progressData.gamification.boostActiveAt(now);
    final awarded = boostActive ? xpEarned * 2 : xpEarned;
    _progressData = await _progress.completeLesson(
      user: user,
      current: _progressData,
      lessonId: lessonId,
      xpEarned: awarded,
      wordsEarned: wordsEarned,
      languageCode: _activeLanguage,
    );
    _progressData = _advanceGamification(xp: awarded, words: wordsEarned);
    notifyListeners();
    return _progressData;
  }

  /// Persists how far the user has read in [bookId].
  Future<void> saveBookProgress(String bookId, int chapterIndex) async {
    final user = _user;
    if (user == null) return;
    _progressData = _progressData.copyWith(
      bookProgress: {..._progressData.bookProgress, bookId: chapterIndex},
    );
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Bookmarks [word] so it appears in "My Words", scoped to the active
  /// learning language.
  Future<void> saveWord(String word) async {
    final user = _user;
    final scope = _activeLanguage;
    if (user == null || _progressData.savedWordsFor(scope).contains(word)) {
      return;
    }
    _progressData = _progressData.addSavedWord(scope, word);
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Removes [word] from "My Words" (active learning language scope).
  Future<void> removeSavedWord(String word) async {
    final user = _user;
    if (user == null) return;
    _progressData = _progressData.removeSavedWord(_activeLanguage, word);
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Puts [word] into the spaced-repetition system at box 1 (due today),
  /// scoped to the active learning language.
  Future<void> addToLeitner(String word) async {
    final user = _user;
    final scope = _activeLanguage;
    if (user == null || _progressData.learningFor(scope).containsKey(word)) {
      return;
    }
    _progressData = _progressData.setLearningWord(scope, word, _scheduler.newState());
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Removes [word] from the spaced-repetition system entirely (active
  /// learning language scope).
  Future<void> removeFromLeitner(String word) async {
    final user = _user;
    if (user == null) return;
    _progressData = _progressData.removeLearningWord(_activeLanguage, word);
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Records a review answer for [word] in the active learning language scope:
  /// a correct recall advances the SM-2-style schedule (box up, interval
  /// grows, ease nudges up); a failure resets the word to box 1 and keeps it
  /// due today so it can be retried.
  Future<void> reviewLeitnerCard(String word, {required bool knew}) async {
    final user = _user;
    if (user == null) return;
    final scope = _activeLanguage;
    final current =
        _progressData.learningFor(scope)[word] ?? _scheduler.newState();
    _progressData = _progressData.setLearningWord(
      scope,
      word,
      _scheduler.review(current, knew: knew),
    );
    var g = _progressData.gamification;
    g = g.rollDaily(_now()).addDaily(reviews: 1);
    if (!knew) g = g.consumeHeart(_now());
    _progressData = _progressData.copyWith(gamification: g);
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// The learning record for [word] in the active learning language scope, or
  /// `null` when the word is not in the review system.
  LearningState? learningState(String word) =>
      _progressData.learningFor(_activeLanguage)[word];

  /// The learning language scope used for word- and lesson-level progress.
  String get _activeLanguage => _language.settings.learningLanguage;

  /// The scheduler driving [reviewLeitnerCard] (exposed so the UI and tests
  /// can read due counts from the same clock).
  SpacedRepetitionScheduler get scheduler => _scheduler;

  // ---------------------------------------------------------------------------
  // Gamification
  // ---------------------------------------------------------------------------

  /// Hearts after the timed refill is applied.
  int get hearts => _progressData.gamification.heartsAt(_now());

  /// Whether an XP boost is currently active.
  bool get boostActive => _progressData.gamification.boostActiveAt(_now());

  /// The weekly league table for the current week, simulated around the
  /// learner's league XP.
  LeagueTable get league {
    final g = _progressData.gamification;
    final now = _now();
    final rolled = g.rollLeagueWeek(now);
    return LeagueTable.simulate(
      weekKey: rolled.leagueWeek ?? GamificationState.dayKey(now),
      playerXp: rolled.leagueXp,
      playerName: _displayName,
    );
  }

  String get _displayName {
    final user = _user;
    final name = user?.displayName ?? user?.email ?? 'You';
    return name.split('@').first;
  }

  /// Owned gamification state (quests, badges, items).
  GamificationState get gamification => _progressData.gamification;

  /// Advances daily quest counters, the weekly league and badge grants after
  /// earning [xp], [words] and [reviews]. Persists once.
  UserProgress _advanceGamification({
    int xp = 0,
    int words = 0,
    int reviews = 0,
  }) {
    final user = _user;
    if (user == null) return _progressData;
    final now = _now();
    var g = _progressData.gamification;
    g = g.rollDaily(now);
    g = g.rollLeagueWeek(now);
    g = g.addDaily(xp: xp, words: words, reviews: reviews);
    g = g.addLeagueXp(xp);
    final tier = GamificationCatalog.tierFor(g.leagueXp);
    if (tier != g.leagueTier) g = g.withTier(tier);
    _progressData = _progressData.copyWith(gamification: g);
    for (final badge in GamificationCatalog.newlyEarned(_progressData, g)) {
      _progressData =
          _progressData.copyWith(gamification: g.withBadge(badge.id));
    }
    _progress.saveProgress(user, _progressData);
    return _progressData;
  }

  /// Consumes one heart (after applying the timed refill) and persists.
  Future<void> consumeHeart() async {
    final user = _user;
    if (user == null || _progressData.gamification.heartsAt(_now()) <= 0) return;
    _progressData = _progressData.copyWith(
      gamification: _progressData.gamification.consumeHeart(_now()),
    );
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Claims [questId]'s reward when complete and unclaimed; awards the quest XP.
  Future<bool> claimQuest(String questId) async {
    final user = _user;
    if (user == null) return false;
    final now = _now();
    var g = _progressData.gamification.rollDaily(now);
    final quest = GamificationCatalog.quests.firstWhere((q) => q.id == questId);
    if (!quest.isComplete(g) || g.claimedQuests.contains(questId)) return false;
    g = g.claimQuest(questId);
    _progressData = _progressData.copyWith(
      gamification: g,
      xp: _progressData.xp + quest.xpReward,
    );
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
    return true;
  }

  /// Activates a double-XP boost for [duration] when an XP boost item is owned.
  Future<bool> activateBoost() async {
    final user = _user;
    final g = _progressData.gamification;
    if (user == null || !g.ownsItem(GamificationState.itemXpBoost)) return false;
    _progressData = _progressData.copyWith(
      gamification: g.activateBoost(_now()),
    );
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
    return true;
  }

  /// Grants [quantity] [itemId] items (used by the shop / tests).
  Future<void> grantItem(String itemId, [int quantity = 1]) async {
    final user = _user;
    if (user == null) return;
    _progressData = _progressData.copyWith(
      gamification: _progressData.gamification.addItem(itemId, quantity),
    );
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Whether the learner owns a streak freeze to protect their streak.
  bool get hasStreakFreeze =>
      _progressData.gamification.ownsItem(GamificationState.itemStreakFreeze);

  /// Whether today's free daily gift (one boost + one streak freeze) can still
  /// be claimed.
  bool get dailyGiftAvailable =>
      !_progressData.gamification.rollDaily(_now()).dailyGiftClaimed;

  /// Claims today's free daily gift: one XP boost and one streak freeze.
  Future<bool> claimDailyGift() async {
    final user = _user;
    if (user == null) return false;
    final g = _progressData.gamification.rollDaily(_now());
    if (g.dailyGiftClaimed) return false;
    final granted = g
        .addItem(GamificationState.itemXpBoost)
        .addItem(GamificationState.itemStreakFreeze)
        .claimDailyGift();
    _progressData = _progressData.copyWith(gamification: granted);
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
    return true;
  }

  /// Purchases [plan] through Stripe and unlocks premium access.
  Future<bool> purchase(SubscriptionPlan plan) async {
    final ok = await _guard(
      () => _stripe.purchase(
        plan: plan,
        accessToken: RemoteApi.instance.accessToken,
      ),
    );
    if (ok && _user != null) {
      _progressData = _progressData.copyWith(subscriptionActive: true);
      await _progress.saveProgress(_user!, _progressData);
      notifyListeners();
    }
    return ok;
  }

  Future<void> _reload() async {
    _user = await _auth.currentUser();
    if (_user != null) {
      _progressData = await _progress.loadProgress(_user!);
    } else {
      _progressData = UserProgress();
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
