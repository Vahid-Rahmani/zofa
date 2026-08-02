import 'learning_state.dart';

/// Serializable learning progress for a single user.
class UserProgress {
  UserProgress({
    this.xp = 0,
    this.streakDays = 0,
    this.lastActiveDay,
    this.completedLessonIds = const [],
    this.wordsLearned = 0,
    this.favoriteBooks = const [],
    this.bookProgress = const {},
    this.subscriptionActive = false,
    this.savedWords = const [],
    Map<String, int>? leitnerBoxes,
    Map<String, LearningState>? learning,
  })  : learning = learning ??
            (leitnerBoxes == null
                ? const {}
                : {
                    for (final e in leitnerBoxes.entries)
                      e.key: LearningState.legacy(box: e.value),
                  });

  final int xp;
  final int streakDays;
  final String? lastActiveDay;
  final List<String> completedLessonIds;
  final int wordsLearned;
  final List<String> favoriteBooks;

  /// book id -> index of the last read chapter.
  final Map<String, int> bookProgress;
  final bool subscriptionActive;

  /// Words the learner has bookmarked ("My Words").
  final List<String> savedWords;

  /// word -> spaced-repetition state (box, stage, interval, due, history).
  /// A word is inside the review system iff it is a key of this map. This is
  /// the canonical source of truth for vocabulary learning.
  final Map<String, LearningState> learning;

  /// Backwards-compatible view of [learning] as word -> Leitner box (1..5).
  Map<String, int> get leitnerBoxes =>
      {for (final e in learning.entries) e.key: e.value.box};

  int get stars => completedLessonIds.length;

  UserProgress copyWith({
    int? xp,
    int? streakDays,
    String? lastActiveDay,
    List<String>? completedLessonIds,
    int? wordsLearned,
    List<String>? favoriteBooks,
    Map<String, int>? bookProgress,
    bool? subscriptionActive,
    List<String>? savedWords,
    Map<String, LearningState>? learning,
  }) {
    return UserProgress(
      xp: xp ?? this.xp,
      streakDays: streakDays ?? this.streakDays,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      favoriteBooks: favoriteBooks ?? this.favoriteBooks,
      bookProgress: bookProgress ?? this.bookProgress,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      savedWords: savedWords ?? this.savedWords,
      learning: learning ?? this.learning,
    );
  }

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    final learningRaw = json['learning'] as Map<String, dynamic>?;
    final legacy = json['leitner_boxes'] as Map<String, dynamic>? ?? const {};
    return UserProgress(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      lastActiveDay: json['last_active_day'] as String?,
      completedLessonIds:
          (json['completed_lesson_ids'] as List<dynamic>? ?? const [])
              .map((e) => e as String)
              .toList(),
      wordsLearned: (json['words_learned'] as num?)?.toInt() ?? 0,
      favoriteBooks: (json['favorite_books'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      bookProgress:
          (json['book_progress'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      subscriptionActive: (json['subscription_active'] as bool?) ?? false,
      savedWords: (json['saved_words'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      learning:
          learningRaw != null && learningRaw.isNotEmpty
              ? learningRaw.map(
                  (key, value) => MapEntry(
                    key,
                    LearningState.fromJson(value as Map<String, dynamic>),
                  ),
                )
              : {
                  for (final e in legacy.entries)
                    e.key: LearningState.legacy(box: (e.value as num).toInt()),
                },
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'streak_days': streakDays,
        'last_active_day': lastActiveDay,
        'completed_lesson_ids': completedLessonIds,
        'words_learned': wordsLearned,
        'favorite_books': favoriteBooks,
        'book_progress': bookProgress,
        'subscription_active': subscriptionActive,
        'saved_words': savedWords,
        'learning': {
          for (final e in learning.entries) e.key: e.value.toJson(),
        },
        'leitner_boxes': leitnerBoxes,
      };
}
