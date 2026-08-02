import 'package:flutter/foundation.dart';

import '../../data/models/app_user.dart';
import '../../data/models/learning_state.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/models/user_progress.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/services/local_store.dart';
import '../../data/services/remote_api.dart';
import '../../data/services/spaced_repetition.dart';
import '../../data/services/stripe_service.dart';
import 'language_controller.dart';

/// Preferences gathered during onboarding.
class OnboardingPrefs {
  const OnboardingPrefs({
    this.nativeLanguage = 'Persian',
    this.level = 'beginner',
    this.motivation = 'travel',
  });

  final String nativeLanguage;
  final String level;
  final String motivation;
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
  })  : _auth = auth ?? AuthRepository(),
        _progress = progress ?? ProgressRepository(),
        _stripe = stripe ?? StripeService.instance,
        _scheduler = scheduler ?? SpacedRepetitionScheduler(),
        _language = language ?? LanguageController();

  final AuthRepository _auth;
  final ProgressRepository _progress;
  final StripeService _stripe;
  final SpacedRepetitionScheduler _scheduler;
  final LanguageController _language;

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
        _user = user.copyWith(
          nativeLanguage: prefs.nativeLanguage,
          level: prefs.level,
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

  /// Marks a lesson as finished, awarding XP and words.
  Future<UserProgress> completeLesson({
    required String lessonId,
    required int xpEarned,
    required int wordsEarned,
  }) async {
    final user = _user;
    if (user == null) return _progressData;
    _progressData = await _progress.completeLesson(
      user: user,
      current: _progressData,
      lessonId: lessonId,
      xpEarned: xpEarned,
      wordsEarned: wordsEarned,
    );
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

  /// Bookmarks [word] so it appears in "My Words".
  Future<void> saveWord(String word) async {
    final user = _user;
    if (user == null || _progressData.savedWords.contains(word)) return;
    _progressData = _progressData.copyWith(
      savedWords: [..._progressData.savedWords, word],
    );
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Removes [word] from "My Words".
  Future<void> removeSavedWord(String word) async {
    final user = _user;
    if (user == null) return;
    _progressData = _progressData.copyWith(
      savedWords:
          _progressData.savedWords.where((w) => w != word).toList(),
    );
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Puts [word] into the spaced-repetition system at box 1 (due today).
  Future<void> addToLeitner(String word) async {
    final user = _user;
    if (user == null || _progressData.learning.containsKey(word)) return;
    _progressData = _progressData.copyWith(
      learning: {..._progressData.learning, word: _scheduler.newState()},
    );
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Removes [word] from the spaced-repetition system entirely.
  Future<void> removeFromLeitner(String word) async {
    final user = _user;
    if (user == null) return;
    final learning = Map<String, LearningState>.from(_progressData.learning)
      ..remove(word);
    _progressData = _progressData.copyWith(learning: learning);
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// Records a review answer for [word]: a correct recall advances the
  /// SM-2-style schedule (box up, interval grows, ease nudges up); a failure
  /// resets the word to box 1 and keeps it due today so it can be retried.
  Future<void> reviewLeitnerCard(String word, {required bool knew}) async {
    final user = _user;
    if (user == null) return;
    final current = _progressData.learning[word] ?? _scheduler.newState();
    final learning = Map<String, LearningState>.from(_progressData.learning)
      ..[word] = _scheduler.review(current, knew: knew);
    _progressData = _progressData.copyWith(learning: learning);
    await _progress.saveProgress(user, _progressData);
    notifyListeners();
  }

  /// The learning record for [word], or `null` when the word is not in the
  /// review system.
  LearningState? learningState(String word) => _progressData.learning[word];

  /// The scheduler driving [reviewLeitnerCard] (exposed so the UI and tests
  /// can read due counts from the same clock).
  SpacedRepetitionScheduler get scheduler => _scheduler;

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
