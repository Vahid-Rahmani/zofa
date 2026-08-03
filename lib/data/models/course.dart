import 'exercise.dart';
import 'exercise_parser.dart';

/// A self-contained teaching unit made of several [Exercise]s.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.icon,
    required this.exercises,
  });

  final String id;
  final String title;
  final String icon;
  final List<Exercise> exercises;

  /// Total number of vocabulary words studied across all exercises (the
  /// flashcard exercise carries the lesson's word list).
  int get wordCount =>
      exercises.fold(0, (sum, exercise) => sum + exercise.words.length);

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      icon: (json['icon'] as String?) ?? '📖',
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map(ExerciseParser.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'exercises': exercises.map(ExerciseParser.toJson).toList(),
    };
  }
}

/// A level groups lessons together, like a chapter in a book.
class CourseLevel {
  const CourseLevel({
    required this.id,
    required this.title,
    required this.lessons,
    this.level = 'A1',
    this.icon = '📘',
    this.description = '',
  });

  final String id;
  final String title;
  final List<Lesson> lessons;

  /// CEFR proficiency level of this level: `A1`, `A2` or `B1`.
  final String level;

  /// Emoji used in the roadmap header for this level.
  final String icon;

  /// One-line description of what the learner will master here.
  final String description;

  factory CourseLevel.fromJson(Map<String, dynamic> json) {
    return CourseLevel(
      id: json['id'] as String,
      title: json['title'] as String,
      level: (json['level'] as String?) ?? 'A1',
      icon: (json['icon'] as String?) ?? '📘',
      description: (json['description'] as String?) ?? '',
      lessons: (json['lessons'] as List<dynamic>)
          .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'level': level,
      'icon': icon,
      'description': description,
      'lessons': lessons.map((e) => e.toJson()).toList(),
    };
  }
}

/// A full course: the top level of the learning roadmap.
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.levels,
    this.language = 'English',
    this.nativeLanguage = 'Persian',
    this.icon = '🗣️',
  });

  final String id;
  final String title;
  final String description;
  final int color;

  /// The language being taught, e.g. `English`.
  final String language;

  /// The learner's native language, e.g. `Persian`.
  final String nativeLanguage;

  /// Emoji used for the course card / header.
  final String icon;

  final List<CourseLevel> levels;

  int get totalLessons => levels.fold(
        0,
        (sum, level) => sum + level.lessons.length,
      );

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      color: (json['color'] as num?)?.toInt() ?? 0xFF3D7BFF,
      language: (json['language'] as String?) ?? 'English',
      nativeLanguage: (json['native_language'] as String?) ?? 'Persian',
      icon: (json['icon'] as String?) ?? '🗣️',
      levels: (json['levels'] as List<dynamic>)
          .map((e) => CourseLevel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'color': color,
      'language': language,
      'native_language': nativeLanguage,
      'icon': icon,
      'levels': levels.map((e) => e.toJson()).toList(),
    };
  }
}
