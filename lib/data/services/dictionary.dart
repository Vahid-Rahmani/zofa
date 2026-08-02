import '../models/course.dart';
import 'seed_content.dart';

/// A small inline dictionary built from all words taught in the bundled
/// courses. In production this can be replaced by a remote dictionary lookup.
abstract final class Dictionary {
  static final Map<String, String> _entries = _build();

  /// Returns the translation for [word], or null when unknown.
  static String? lookup(String word) {
    final normalized = word.toLowerCase().trim();
    return _entries[normalized];
  }

  static Map<String, String> _build() {
    final map = <String, String>{};
    for (final course in SeedContent.courses) {
      _collectCourse(course, map);
    }
    return map;
  }

  static void _collectCourse(Course course, Map<String, String> map) {
    for (final level in course.levels) {
      for (final lesson in level.lessons) {
        for (final exercise in lesson.exercises) {
          map.addAll(exercise.pairs);
        }
      }
    }
  }
}
