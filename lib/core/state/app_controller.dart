import 'package:flutter/foundation.dart';

import '../../data/models/app_user.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/models/user_progress.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/services/local_store.dart';
import '../../data/services/remote_api.dart';
import '../../data/services/stripe_service.dart';

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
  })  : _auth = auth ?? AuthRepository(),
        _progress = progress ?? ProgressRepository(),
        _stripe = stripe ?? StripeService.instance;

  final AuthRepository _auth;
  final ProgressRepository _progress;
  final StripeService _stripe;

  AppUser? _user;
  UserProgress _progressData = const UserProgress();
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
    _progressData = const UserProgress();
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
      _progressData = const UserProgress();
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
