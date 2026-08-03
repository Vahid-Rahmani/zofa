import 'gamification_state.dart';
import 'learning_state.dart';

/// Serializable learning progress for a single user.
///
/// Word- and lesson-level progress is scoped per learning language so that
/// switching the language pair (e.g. Persian+German -> English+Spanish) never
/// mixes `Apfel` with `apple` progress. Switching back restores the previous
/// progress untouched; switching away never deletes it.
///
/// Data saved before this pairing was introduced is migrated into the `en`
/// scope on load so nothing is lost.
class UserProgress {
  UserProgress({
    this.xp = 0,
    this.streakDays = 0,
    this.lastActiveDay,
    List<String>? completedLessonIds,
    this.wordsLearned = 0,
    this.favoriteBooks = const [],
    this.bookProgress = const {},
    this.subscriptionActive = false,
    List<String>? savedWords,
    Map<String, int>? leitnerBoxes,
    Map<String, LearningState>? learning,
    Map<String, List<String>>? completedLessonsByLang,
    Map<String, List<String>>? savedWordsByLang,
    Map<String, Map<String, LearningState>>? learningByLang,
    GamificationState? gamification,
  })  : _completedLessonsByLang =
            Map<String, List<String>>.from(completedLessonsByLang ?? {}),
        _savedWordsByLang =
            Map<String, List<String>>.from(savedWordsByLang ?? {}),
        _learningByLang =
            Map<String, Map<String, LearningState>>.from(learningByLang ?? {}),
        gamification = gamification ?? const GamificationState() {
    // Flat/legacy data always belongs to the English scope (all pre-pairing
    // sessions were English). Merge instead of replacing so nothing is lost.
    if (learning != null && learning.isNotEmpty) {
      _learningByLang['en'] = {...?_learningByLang['en'], ...learning};
    }
    if (leitnerBoxes != null && leitnerBoxes.isNotEmpty) {
      _learningByLang['en'] = {
        ...?_learningByLang['en'],
        ...{
          for (final e in leitnerBoxes.entries)
            e.key: LearningState.legacy(box: e.value),
        },
      };
    }
    if (savedWords != null && savedWords.isNotEmpty) {
      _savedWordsByLang['en'] = {...?_savedWordsByLang['en'], ...savedWords}.toList();
    }
    if (completedLessonIds != null && completedLessonIds.isNotEmpty) {
      _completedLessonsByLang['en'] = {
        ...?_completedLessonsByLang['en'],
        ...completedLessonIds,
      }.toList();
    }
  }

  final int xp;
  final int streakDays;
  final String? lastActiveDay;
  final int wordsLearned;
  final List<String> favoriteBooks;

  /// book id -> index of the last read chapter.
  final Map<String, int> bookProgress;
  final bool subscriptionActive;

  /// learning language -> lessons completed for that language.
  final Map<String, List<String>> _completedLessonsByLang;

  /// learning language -> words bookmarked for that language ("My Words").
  final Map<String, List<String>> _savedWordsByLang;

  /// learning language -> word -> spaced-repetition state. A word is inside the
  /// review system iff it is a key of its language's map. This is the canonical
  /// source of truth for vocabulary learning.
  final Map<String, Map<String, LearningState>> _learningByLang;

  /// Duolingo-style gamification state (hearts, boosts, daily quests, weekly
  /// league, badges). Shared across language scopes.
  final GamificationState gamification;

  /// Lessons completed for the English scope. Prefer [completedLessonsFor]
  /// keyed by the active learning language.
  List<String> get completedLessonIds =>
      _completedLessonsByLang['en'] ?? const <String>[];

  /// Bookmarked words for the English scope. Prefer [savedWordsFor].
  List<String> get savedWords => _savedWordsByLang['en'] ?? const <String>[];

  /// Learning records for the English scope. Prefer [learningFor].
  Map<String, LearningState> get learning =>
      _learningByLang['en'] ?? const <String, LearningState>{};

  /// English-scope word -> box (1..5). Prefer [leitnerBoxesFor].
  Map<String, int> get leitnerBoxes =>
      {for (final e in learning.entries) e.key: e.value.box};

  /// Lessons completed for [languageCode].
  List<String> completedLessonsFor(String languageCode) =>
      _completedLessonsByLang[languageCode] ?? const <String>[];

  /// Bookmarked words for [languageCode].
  List<String> savedWordsFor(String languageCode) =>
      _savedWordsByLang[languageCode] ?? const <String>[];

  /// Word learning records for [languageCode].
  Map<String, LearningState> learningFor(String languageCode) =>
      _learningByLang[languageCode] ?? const <String, LearningState>{};

  /// [languageCode] word -> box (1..5).
  Map<String, int> leitnerBoxesFor(String languageCode) =>
      {for (final e in learningFor(languageCode).entries) e.key: e.value.box};

  /// Completed-lesson stars for [languageCode].
  int starCountFor(String languageCode) =>
      completedLessonsFor(languageCode).length;

  /// Total completed lessons across every language scope.
  int get stars =>
      _completedLessonsByLang.values.fold(0, (sum, list) => sum + list.length);

  /// Adds [lessonId] to [languageCode]'s completed lessons (deduplicated).
  UserProgress addCompletedLesson(String languageCode, String lessonId) {
    final list = {
      ...completedLessonsFor(languageCode),
      lessonId,
    }.toList();
    return copyWith(completedLessonsByLang: {
      ..._completedLessonsByLang,
      languageCode: list,
    });
  }

  /// Bookmarks [word] for [languageCode] (deduplicated).
  UserProgress addSavedWord(String languageCode, String word) {
    final list = {...savedWordsFor(languageCode), word}.toList();
    return copyWith(savedWordsByLang: {
      ..._savedWordsByLang,
      languageCode: list,
    });
  }

  /// Removes [word] from [languageCode]'s bookmarks.
  UserProgress removeSavedWord(String languageCode, String word) {
    return copyWith(savedWordsByLang: {
      ..._savedWordsByLang,
      languageCode: savedWordsFor(languageCode)
          .where((w) => w != word)
          .toList(),
    });
  }

  /// Records [state] for [word] in [languageCode]'s review system.
  UserProgress setLearningWord(
    String languageCode,
    String word,
    LearningState state,
  ) {
    return copyWith(learningByLang: {
      ..._learningByLang,
      languageCode: {...learningFor(languageCode), word: state},
    });
  }

  /// Removes [word] from [languageCode]'s review system entirely.
  UserProgress removeLearningWord(String languageCode, String word) {
    final updated = Map<String, LearningState>.from(learningFor(languageCode))
      ..remove(word);
    return copyWith(learningByLang: {
      ..._learningByLang,
      languageCode: updated,
    });
  }

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
    Map<String, List<String>>? completedLessonsByLang,
    Map<String, List<String>>? savedWordsByLang,
    Map<String, Map<String, LearningState>>? learningByLang,
    GamificationState? gamification,
  }) {
    return UserProgress(
      xp: xp ?? this.xp,
      streakDays: streakDays ?? this.streakDays,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      completedLessonIds: completedLessonIds,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      favoriteBooks: favoriteBooks ?? this.favoriteBooks,
      bookProgress: bookProgress ?? this.bookProgress,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      savedWords: savedWords,
      learning: learning,
      completedLessonsByLang: completedLessonsByLang ?? _completedLessonsByLang,
      savedWordsByLang: savedWordsByLang ?? _savedWordsByLang,
      learningByLang: learningByLang ?? _learningByLang,
      gamification: gamification ?? this.gamification,
    );
  }

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    final learningRaw = json['learning'] as Map<String, dynamic>? ?? const {};
    final legacyBoxes = json['leitner_boxes'] as Map<String, dynamic>? ?? const {};

    // The `learning` key used to be flat (word -> state); it is now nested
    // (language -> word -> state). Discriminate on the depth of the maps: a
    // state's own JSON values are scalars, while a language map holds state
    // maps, so nested data is two levels of maps deep.
    final nestedLearning = learningRaw.isNotEmpty &&
        learningRaw.values.first is Map<String, dynamic> &&
        (learningRaw.values.first as Map<String, dynamic>)
            .values
            .every((v) => v is Map<String, dynamic>);
    final flatLearning = !nestedLearning && learningRaw.isNotEmpty
        ? learningRaw.map(
            (key, value) => MapEntry(
              key,
              LearningState.fromJson(value as Map<String, dynamic>),
            ),
          )
        : null;

    // `saved_words` used to be a plain list; it is now a language -> list map.
    final rawSavedWords = json['saved_words'];
    final savedNested = rawSavedWords is Map<String, dynamic>
        ? rawSavedWords.map(
            (code, list) => MapEntry(
              code,
              (list as List<dynamic>).cast<String>().toList(),
            ),
          )
        : null;
    final savedFlat = rawSavedWords is List
        ? rawSavedWords.cast<String>().toList()
        : null;

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
      savedWords: savedFlat,
      learning: flatLearning,
      leitnerBoxes: flatLearning == null && legacyBoxes.isNotEmpty
          ? {
              for (final e in legacyBoxes.entries)
                e.key: (e.value as num).toInt(),
            }
          : null,
      completedLessonsByLang: _parseLessonsByLang(
        json['completed_lessons'],
      ),
      savedWordsByLang: savedNested,
      learningByLang: nestedLearning
          ? (json['learning'] as Map<String, dynamic>).map(
              (code, inner) => MapEntry(
                code,
                (inner as Map<String, dynamic>).map(
                  (word, state) => MapEntry(
                    word,
                    LearningState.fromJson(state as Map<String, dynamic>),
                  ),
                ),
              ),
            )
          : null,
      gamification:
          GamificationState.fromJson(json['gamification'] as Map<String, dynamic>?),
    );
  }

  static Map<String, List<String>> _parseLessonsByLang(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const {};
    return raw.map(
      (code, list) => MapEntry(
        code,
        (list as List<dynamic>).cast<String>().toList(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'streak_days': streakDays,
        'last_active_day': lastActiveDay,
        'completed_lessons': _completedLessonsByLang,
        'words_learned': wordsLearned,
        'favorite_books': favoriteBooks,
        'book_progress': bookProgress,
        'subscription_active': subscriptionActive,
        'saved_words': _savedWordsByLang,
        'learning': {
          for (final lang in _learningByLang.entries)
            lang.key: {
              for (final e in lang.value.entries) e.key: e.value.toJson(),
            },
        },
        'gamification': gamification.toJson(),
      };
}
