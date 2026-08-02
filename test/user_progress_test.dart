import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/user_progress.dart';

void main() {
  group('UserProgress', () {
    test('round-trips through JSON', () {
      const progress = UserProgress(
        xp: 120,
        streakDays: 4,
        lastActiveDay: '2026-08-02',
        completedLessonIds: ['a', 'b'],
        wordsLearned: 9,
        favoriteBooks: ['book_little_light'],
        bookProgress: {'book_little_light': 2},
        subscriptionActive: true,
        savedWords: ['apple', 'book'],
        leitnerBoxes: {'apple': 1, 'book': 3},
      );

      final restored = UserProgress.fromJson(progress.toJson());

      expect(restored.xp, 120);
      expect(restored.streakDays, 4);
      expect(restored.lastActiveDay, '2026-08-02');
      expect(restored.completedLessonIds, ['a', 'b']);
      expect(restored.wordsLearned, 9);
      expect(restored.favoriteBooks, ['book_little_light']);
      expect(restored.bookProgress, {'book_little_light': 2});
      expect(restored.subscriptionActive, isTrue);
      expect(restored.savedWords, ['apple', 'book']);
      expect(restored.leitnerBoxes, {'apple': 1, 'book': 3});
    });

    test('copyWith keeps untouched fields', () {
      const progress = UserProgress(xp: 10);
      final updated = progress.copyWith(wordsLearned: 3);

      expect(updated.xp, 10);
      expect(updated.wordsLearned, 3);
      expect(updated.savedWords, isEmpty);
      expect(updated.leitnerBoxes, isEmpty);
    });
  });
}
