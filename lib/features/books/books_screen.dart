import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/models/book.dart';
import '../../data/services/seed_content.dart';
import 'reader_screen.dart';

/// The Books tab: an interactive library where every story teaches words.
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    context.watch<UiTranslationController?>();

    final grouped = <String, List<Book>>{};
    for (final book in SeedContent.books) {
      grouped.putIfAbsent(book.level, () => []).add(book);
    }
    const levelOrder = ['A1', 'A2', 'B1'];

    return Scaffold(
      appBar: AppBar(
        title: const TrText('Books'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: TrText(
                  'Tap any word to learn it.',
                  style: TextStyle(color: ZovaColors.textSecondary),
                ),
              ),
            ),
            for (final level in levelOrder)
              if ((grouped[level] ?? const []).isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: _LevelHeader(level: level),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.separated(
                    itemCount: grouped[level]!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final book = grouped[level]![index];
                      final lastRead =
                          controller.progress.bookProgress[book.id] ?? -1;
                      final isNew = lastRead < 0;
                      return _BookCard(
                        book: book,
                        progressLabel: isNew
                            ? context.tr('New')
                            : context.trTempl('Chapter {0} of {1}',
                                [lastRead + 1, book.chapters.length]),
                        isNew: isNew,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ReaderScreen(book: book),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      _ => ZovaColors.warning,
    };
    final label = switch (level) {
      'A1' => 'A1 · Beginner',
      'A2' => 'A2 · Elementary',
      _ => 'B1 · Intermediate',
    };
    final count = SeedContent.books.where((b) => b.level == level).length;
    context.watch<UiTranslationController?>();

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          context.tr(label),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ZovaColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          context.trTempl(count == 1 ? '{0} book' : '{0} books', [count]),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ZovaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.progressLabel,
    required this.isNew,
    required this.onTap,
  });

  final Book book;
  final String progressLabel;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ZovaColors.gradientStart, ZovaColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(book.cover, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${book.author} · ${book.difficulty}',
                          style: const TextStyle(
                            color: ZovaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LevelChip(level: book.level),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progressLabel,
                      style: TextStyle(
                        color: isNew
                            ? ZovaColors.primary
                            : ZovaColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ZovaColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      _ => ZovaColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
