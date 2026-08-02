import '../models/learning_state.dart';

/// Deterministic, clock-injected spaced-repetition scheduler.
///
/// Implements an SM-2-style algorithm on top of the Leitner boxes already used
/// by the app:
///
/// * A correct recall advances the box (capped at [maxBox]) and grows the
///   interval SM-2 style: 1 day after the first success, 6 days after the
///   second, then `interval * ease` after that.
/// * A failed recall drops the word back to box 1, resets repetitions, lowers
///   the ease factor and keeps the word due today so it can be retried in the
///   same session.
/// * The ease factor is bounded to `[minEase, maxEase]` and never goes above
///   the SM-2 ceiling of 2.5 from the default.
///
/// The clock is injected (defaults to `DateTime.now`) so scheduling logic is
/// fully unit-testable and never depends on the real wall clock.
class SpacedRepetitionScheduler {
  SpacedRepetitionScheduler({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const int maxBox = 5;
  static const double minEase = 1.3;
  static const double maxEase = 2.5;
  static const double easeStepUp = 0.05;
  static const double easeStepDown = 0.20;

  /// Intervals at which a word counts as mastered / long-term retained.
  static const int masteredIntervalDays = 21;

  final DateTime Function() _now;

  /// The scheduler's current "now". Tests advance this by injecting a mutable
  /// closure.
  DateTime get now => _now();

  /// A fresh state for a word that just entered the system: box 1, due now.
  LearningState newState() => LearningState(due: now);

  /// Whether [state] is due right now.
  bool isDue(LearningState state) => state.isDueAt(now);

  /// All states in [states] whose due date has passed, ordered by due date
  /// (most urgent first). This is the daily review queue.
  List<LearningState> dueQueue(Iterable<LearningState> states) {
    final at = now;
    final due = [
      for (final state in states)
        if (state.isDueAt(at)) state,
    ]..sort((a, b) => a.due.compareTo(b.due));
    return due;
  }

  /// Number of cards due right now (the daily due count).
  int dailyDueCount(Iterable<LearningState> states) =>
      dueQueue(states).length;

  /// Applies one review answer to [state], returning the new state.
  LearningState review(LearningState state, {required bool knew}) {
    final at = now;
    return knew ? _succeed(state, at) : _fail(state, at);
  }

  LearningState _succeed(LearningState state, DateTime at) {
    final reps = state.repetitions + 1;
    final interval = _nextInterval(state, reps);
    return state.copyWith(
      box: (state.box + 1).clamp(1, maxBox),
      stage: _stageFor(reps, interval),
      repetitions: reps,
      intervalDays: interval,
      ease: (state.ease + easeStepUp).clamp(minEase, maxEase),
      due: at.add(Duration(days: interval)),
      lastReviewed: at,
      correctCount: state.correctCount + 1,
    );
  }

  LearningState _fail(LearningState state, DateTime at) {
    return state.copyWith(
      box: 1,
      stage: LearningStage.learning,
      repetitions: 0,
      intervalDays: 1,
      ease: (state.ease - easeStepDown).clamp(minEase, maxEase),
      due: at,
      lastReviewed: at,
      incorrectCount: state.incorrectCount + 1,
    );
  }

  int _nextInterval(LearningState state, int newRepetitions) {
    if (newRepetitions == 1) return 1;
    if (newRepetitions == 2) return 6;
    final base = state.intervalDays > 0 ? state.intervalDays : 6;
    return (base * state.ease).round().clamp(1, 365);
  }

  LearningStage _stageFor(int repetitions, int intervalDays) {
    if (repetitions == 0) return LearningStage.newWord;
    if (intervalDays >= masteredIntervalDays) return LearningStage.mastered;
    if (repetitions <= 2) return LearningStage.learning;
    return LearningStage.review;
  }
}
