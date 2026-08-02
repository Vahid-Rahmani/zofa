import '../../core/config/env_config.dart';
import '../models/app_user.dart';
import '../models/user_progress.dart';
import '../services/local_store.dart';
import '../services/remote_api.dart';

/// Reads and writes learning progress for the signed-in user.
class ProgressRepository {
  ProgressRepository({
    RemoteApi? remote,
  }) : _remote = remote ?? RemoteApi.instance;

  final RemoteApi _remote;

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

  /// Marks a lesson as completed and awards XP and learned words.
  Future<UserProgress> completeLesson({
    required AppUser user,
    required UserProgress current,
    required String lessonId,
    required int xpEarned,
    required int wordsEarned,
  }) async {
    final completed = List<String>.from(current.completedLessonIds);
    if (!completed.contains(lessonId)) {
      completed.add(lessonId);
    }
    final updated = current.copyWith(
      xp: current.xp + xpEarned,
      wordsLearned: current.wordsLearned + wordsEarned,
      completedLessonIds: completed,
      lastActiveDay: _todayKey(),
    );
    await saveProgress(user, updated);
    return updated;
  }

  /// Recomputes the streak. A new day extends it; the first day starts at 1.
  Future<UserProgress> touchDailyStreak(
    AppUser user,
    UserProgress current,
  ) async {
    final today = _todayKey();
    if (current.lastActiveDay == today) return current;

    final updated = current.copyWith(
      lastActiveDay: today,
      streakDays: current.lastActiveDay == null
          ? 1
          : current.streakDays + 1,
    );
    await saveProgress(user, updated);
    return updated;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
