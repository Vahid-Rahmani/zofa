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
  });

  final String id;
  final String title;
  final List<Lesson> lessons;

  factory CourseLevel.fromJson(Map<String, dynamic> json) {
    return CourseLevel(
      id: json['id'] as String,
      title: json['title'] as String,
      lessons: (json['lessons'] as List<dynamic>)
          .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
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
  });

  final String id;
  final String title;
  final String description;
  final int color;
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
      'levels': levels.map((e) => e.toJson()).toList(),
    };
  }
}
