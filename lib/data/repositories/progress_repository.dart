import '../../core/config/env_config.dart';
import '../models/app_user.dart';
import '../models/gamification_state.dart';
import '../models/user_progress.dart';
import '../services/local_store.dart';
import '../services/remote_api.dart';

/// Reads and writes learning progress for the signed-in user.
class ProgressRepository {
  ProgressRepository({
    RemoteApi? remote,
    DateTime Function()? now,
  })  : _remote = remote ?? RemoteApi.instance,
        _now = now ?? DateTime.now;

  final RemoteApi _remote;
  final DateTime Function() _now;

  Future<UserProgress> loadProgress(AppUser user) async {
    if (isDemoMode) {
      return LocalStore.getProgress();
    }
    final remoteProgress = await _remote.fetchProgress(user.id);
    if (remoteProgress == null) {
      final local = await LocalStore.getProgress();
      return local;
    }
    return remoteProgress;
  }

  bool get isDemoMode => EnvConfig.isDemoMode;

  Future<void> saveProgress(AppUser user, UserProgress progress) async {
    await LocalStore.saveProgress(progress);
    if (!isDemoMode && user.id.isNotEmpty) {
      await _remote.upsertProgress(user.id, progress);
    }
  }

  /// Marks a lesson as completed (scoped to [languageCode]) and awards XP and
  /// learned words.
  Future<UserProgress> completeLesson({
    required AppUser user,
    required UserProgress current,
    required String lessonId,
    required int xpEarned,
    required int wordsEarned,
    String languageCode = 'en',
  }) async {
    final updated = current
        .addCompletedLesson(languageCode, lessonId)
        .copyWith(
          xp: current.xp + xpEarned,
          wordsLearned: current.wordsLearned + wordsEarned,
          lastActiveDay: _todayKey(),
        );
    await saveProgress(user, updated);
    return updated;
  }

  /// Recomputes the streak. A new day extends it; the first day starts at 1.
  /// When a full day is skipped the streak resets to 1 — unless the learner
  /// owns a [GamificationState.itemStreakFreeze], which is consumed to keep the
  /// streak intact.
  Future<UserProgress> touchDailyStreak(
    AppUser user,
    UserProgress current,
  ) async {
    final today = _todayKey();
    if (current.lastActiveDay == today) return current;

    final last = current.lastActiveDay;
    final skippedDay = last != null && !_isConsecutive(last, today);
    var gamification = current.gamification;
    var freezeUsed = false;
    if (skippedDay && gamification.ownsItem(GamificationState.itemStreakFreeze)) {
      gamification = gamification.spendItem(GamificationState.itemStreakFreeze);
      freezeUsed = true;
    }

    final streakDays = last == null
        ? 1
        : skippedDay && !freezeUsed
            ? 1
            : current.streakDays + 1;

    final updated = current.copyWith(
      lastActiveDay: today,
      streakDays: streakDays,
      gamification: gamification,
    );
    await saveProgress(user, updated);
    return updated;
  }

  /// Whether [previous] (yyyy-MM-dd) is the calendar day before [today].
  bool _isConsecutive(String previous, String today) {
    final previousDate = DateTime.tryParse(previous);
    final todayDate = DateTime.tryParse(today);
    if (previousDate == null || todayDate == null) return false;
    return todayDate.difference(previousDate).inDays == 1;
  }

  String _todayKey() {
    final now = _now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
