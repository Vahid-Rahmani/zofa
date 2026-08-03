import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/models/course.dart';
import '../../data/models/translation_language.dart';
import '../../data/services/seed_content.dart';
import 'lesson/lesson_screen.dart';

/// The Courses tab: shows the roadmap with levels and lessons plus the
/// user's streak and daily progress.
///
/// The roadmap follows the active learning language from [LanguageController]
/// and rebuilds when the language pair changes. Languages without a bundled
/// course (e.g. Spanish) get an honest "coming soon" state.
///
/// Lessons unlock sequentially across the whole roadmap: a lesson is playable
/// only when the previous lesson in the flat course order is completed.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  @override
  Widget build(BuildContext context) {
    final languageCode =
        context.watch<LanguageController>().settings.learningLanguage;
    context.watch<UiTranslationController?>();
    return FutureBuilder<Course?>(
      future: SeedContent.courseFor(languageCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                context.tr("Couldn't load the course. Please try again."),
                style: const TextStyle(color: ZovaColors.textSecondary),
              ),
            ),
          );
        }
        final course = snapshot.data;
        if (course == null) {
          return _ComingSoon(languageCode: languageCode);
        }
        return _buildRoadmap(context, course);
      },
    );
  }

  Widget _buildRoadmap(BuildContext context, Course course) {
    final controller = context.watch<AppController>();
    final languageCode =
        context.read<LanguageController>().settings.learningLanguage;
    final completedIds = controller.progress.completedLessonsFor(languageCode);

    final roadmap = <_RoadmapEntry>[];
    for (final level in course.levels) {
      for (final lesson in level.lessons) {
        roadmap.add(_RoadmapEntry(level: level, lesson: lesson));
      }
    }

    final levelStarts = <int>[];
    var running = 0;
    for (final level in course.levels) {
      levelStarts.add(running);
      running += level.lessons.length;
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                language: course.language,
                streak: controller.progress.streakDays,
                xp: controller.progress.xp,
                completed: completedIds.length,
                total: course.totalLessons,
              ),
            ),
            for (final (index, level) in course.levels.indexed)
              SliverToBoxAdapter(
                child: _LevelSection(
                  level: level,
                  entries:
                      roadmap.where((entry) => entry.level == level).toList(),
                  roadmap: roadmap,
                  startIndex: levelStarts[index],
                  completedIds: completedIds,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _RoadmapEntry {
  const _RoadmapEntry({required this.level, required this.lesson});

  final CourseLevel level;
  final Lesson lesson;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.language,
    required this.streak,
    required this.xp,
    required this.completed,
    required this.total,
  });

  final String language;
  final int streak;
  final int xp;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    context.watch<UiTranslationController?>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.trTempl('Learn {0}', [language]),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const TrText(
                      'Small steps, every day.',
                      style: TextStyle(color: ZovaColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _StatChip(
                icon: Icons.local_fire_department,
                color: ZovaColors.warning,
                value: '$streak',
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: Icons.bolt,
                color: ZovaColors.primary,
                value: '$xp',
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ZovaColors.gradientStart, ZovaColors.gradientEnd],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TrText(
                    'Roadmap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.trTempl('{0} of {1} lessons completed', [
                      completed,
                      total,
                    ]),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: ZovaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelSection extends StatelessWidget {
  const _LevelSection({
    required this.level,
    required this.entries,
    required this.roadmap,
    required this.completedIds,
    required this.startIndex,
  });

  final CourseLevel level;
  final List<_RoadmapEntry> entries;
  final List<_RoadmapEntry> roadmap;
  final List<String> completedIds;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final done =
        entries.where((e) => completedIds.contains(e.lesson.id)).length;
    context.watch<UiTranslationController?>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(level.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.description.isEmpty
                          ? context.trTempl('{0} lessons', [
                              level.lessons.length,
                            ])
                          : level.description,
                      style: const TextStyle(color: ZovaColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _LevelBadge(level: level.level),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.trTempl('{0} of {1} lessons done', [
              done,
              entries.length,
            ]),
            style: const TextStyle(
              color: ZovaColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final (index, entry) in entries.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LessonCard(
                lesson: entry.lesson,
                isCompleted: completedIds.contains(entry.lesson.id),
                isLocked: _isLocked(startIndex + index),
              ),
            ),
        ],
      ),
    );
  }

  /// A lesson is locked unless it is the first of the whole course or its
  /// globally preceding lesson is completed.
  bool _isLocked(int globalIndex) {
    if (globalIndex == 0) return false;
    final previous = roadmap[globalIndex - 1].lesson.id;
    return !completedIds.contains(previous);
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      _ => ZovaColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.isCompleted,
    required this.isLocked,
  });

  final Lesson lesson;
  final bool isCompleted;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: CircleAvatar(
          backgroundColor: isCompleted
              ? ZovaColors.success.withValues(alpha: 0.15)
              : ZovaColors.surfaceRaised,
          child: Text(lesson.icon),
        ),
        title: Text(
          lesson.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: ZovaColors.textPrimary,
          ),
        ),
        subtitle: Text(
          isCompleted
              ? context.tr('Completed')
              : isLocked
                  ? context.tr('Locked')
                  : context.trTempl('{0} words · {1} exercises', [
                      lesson.wordCount,
                      lesson.exercises.length,
                    ]),
          style: TextStyle(
            color: isLocked
                ? ZovaColors.textSecondary.withValues(alpha: 0.5)
                : ZovaColors.textSecondary,
          ),
        ),
        trailing: isCompleted
            ? const Icon(Icons.check_circle, color: ZovaColors.success)
            : isLocked
                ? const Icon(Icons.lock, color: ZovaColors.textSecondary)
                : const Icon(Icons.play_circle_fill, color: ZovaColors.primary),
        onTap: isLocked
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonScreen(
                      lesson: lesson,
                      onComplete: () {},
                    ),
                  ),
                );
              },
      ),
    );
  }
}

/// Shown when the active learning language has no bundled roadmap course yet.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final name = TranslationLanguage.byCode(languageCode)?.name ?? languageCode;
    context.watch<UiTranslationController?>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚧', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  context.trTempl('{0} course coming soon', [name]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.trTempl(
                    'The dictionary, flashcards and reviews already work for '
                    '{0}. A full structured course is on the way.',
                    [name],
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ZovaColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
