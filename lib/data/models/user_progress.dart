/// Serializable learning progress for a single user.
class UserProgress {
  const UserProgress({
    this.xp = 0,
    this.streakDays = 0,
    this.lastActiveDay,
    this.completedLessonIds = const [],
    this.wordsLearned = 0,
    this.favoriteBooks = const [],
    this.bookProgress = const {},
    this.subscriptionActive = false,
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
    );
  }

  factory UserProgress.fromJson(Map<String, dynamic> json) {
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
      };
}
