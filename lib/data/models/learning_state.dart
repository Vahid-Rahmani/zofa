/// Learning stage of a word inside the spaced-repetition system.
///
/// Mirrors the common "new / learning / review / mastered" taxonomy used by
/// modern SRS apps: a word is *new* until its first review, *learning* while
/// it is being introduced, *review* once it is retained across days, and
/// *mastered* once its interval grows past a long-term threshold.
enum LearningStage {
  newWord('new'),
  learning('learning'),
  review('review'),
  mastered('mastered');

  const LearningStage(this.label);

  /// Stable serialised label.
  final String label;

  static LearningStage fromLabel(String? label) {
    switch (label) {
      case 'new':
        return LearningStage.newWord;
      case 'review':
        return LearningStage.review;
      case 'mastered':
        return LearningStage.mastered;
      default:
        return LearningStage.learning;
    }
  }
}

/// Immutable per-word learning record produced by the
/// `SpacedRepetitionScheduler`.
///
/// Combines the Leitner box (1..5, drives the box UI and grouping) with the
/// SM-2-style scheduling fields: repetitions, interval, ease factor, due date
/// and a correct/incorrect review history. The word itself is the key of the
/// owning map in `UserProgress.learning`, so it is not stored here.
class LearningState {
  const LearningState({
    this.box = 1,
    this.stage = LearningStage.newWord,
    this.repetitions = 0,
    this.intervalDays = 0,
    this.ease = 2.5,
    required this.due,
    this.lastReviewed,
    this.correctCount = 0,
    this.incorrectCount = 0,
  });

  /// Leitner box 1..5. Box 1 is reviewed most often.
  final int box;

  /// Coarse learning stage derived from [repetitions] and [intervalDays].
  final LearningStage stage;

  /// Number of successful reviews in the current run (resets on failure).
  final int repetitions;

  /// Days until the next review; 0 before the first successful review.
  final int intervalDays;

  /// SM-2 ease factor, bounded to [SpacedRepetitionScheduler.minEase]..max.
  final double ease;

  /// When the next review is due. An entry is due when [isDueAt] the current
  /// time is not before this stamp.
  final DateTime due;

  /// When this word was last reviewed (success or failure), if ever.
  final DateTime? lastReviewed;

  /// Lifetime count of correct recalls.
  final int correctCount;

  /// Lifetime count of failed recalls.
  final int incorrectCount;

  /// Whether a review is due at [at] (due date has passed or is now).
  bool isDueAt(DateTime at) => !due.isAfter(at);

  LearningState copyWith({
    int? box,
    LearningStage? stage,
    int? repetitions,
    int? intervalDays,
    double? ease,
    DateTime? due,
    DateTime? lastReviewed,
    int? correctCount,
    int? incorrectCount,
  }) {
    return LearningState(
      box: box ?? this.box,
      stage: stage ?? this.stage,
      repetitions: repetitions ?? this.repetitions,
      intervalDays: intervalDays ?? this.intervalDays,
      ease: ease ?? this.ease,
      due: due ?? this.due,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
    );
  }

  factory LearningState.fromJson(Map<String, dynamic> json) {
    return LearningState(
      box: ((json['box'] as num?)?.toInt() ?? 1).clamp(1, 5),
      stage: LearningStage.fromLabel(json['stage'] as String?),
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      intervalDays: (json['interval_days'] as num?)?.toInt() ?? 0,
      ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
      due: DateTime.tryParse(json['due'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastReviewed: DateTime.tryParse(json['last_reviewed'] as String? ?? ''),
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      incorrectCount: (json['incorrect_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'box': box,
        'stage': stage.label,
        'repetitions': repetitions,
        'interval_days': intervalDays,
        'ease': ease,
        'due': due.toIso8601String(),
        'last_reviewed': lastReviewed?.toIso8601String(),
        'correct_count': correctCount,
        'incorrect_count': incorrectCount,
      };

  /// A stand-in state used when migrating a legacy Leitner box map (no
  /// scheduling metadata). Box is preserved, the word counts as due so the
  /// learner can review it today; the scheduler rewrites the record on the
  /// first answer.
  factory LearningState.legacy({required int box}) {
    final b = box.clamp(1, 5);
    return LearningState(
      box: b,
      stage: b >= 5 ? LearningStage.review : LearningStage.learning,
      repetitions: b,
      intervalDays: b,
      due: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
