import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/models/grammar_topic.dart';
import '../../data/services/grammar_content.dart';

/// Grammar hub: a curated list of English grammar points, grouped by level.
class GrammarScreen extends StatelessWidget {
  const GrammarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const levelOrder = ['A1', 'A2', 'B1'];

    return Scaffold(
      appBar: AppBar(title: const TrText('Grammar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const TrText(
              'Understand how English works',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const TrText(
              'Short explanations with real examples, from A1 to B1.',
              style: TextStyle(color: ZovaColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            for (final level in levelOrder)
              _LevelGroup(
                level: level,
                topics: GrammarContent.topics
                    .where((t) => t.level == level)
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LevelGroup extends StatelessWidget {
  const _LevelGroup({required this.level, required this.topics});

  final String level;
  final List<GrammarTopic> topics;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      _ => ZovaColors.warning,
    };
    context.watch<UiTranslationController?>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              level,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.trTempl('{0} topics', [topics.length]),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ZovaColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final topic in topics) ...[
          _TopicCard(
            topic: topic,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GrammarDetailScreen(topic: topic),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 22),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.onTap});

  final GrammarTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZovaColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(topic.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      topic.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ZovaColors.textSecondary,
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

/// Full explanation for a single grammar topic.
class GrammarDetailScreen extends StatelessWidget {
  const GrammarDetailScreen({super.key, required this.topic});

  final GrammarTopic topic;

  @override
  Widget build(BuildContext context) {
    final levelColor = switch (topic.level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      _ => ZovaColors.warning,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title, style: const TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZovaColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(topic.icon, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        topic.faTitle,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(color: ZovaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    topic.level,
                    style: TextStyle(
                      color: levelColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              topic.explanation,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 22),
            const TrText(
              'Examples',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            for (final example in topic.examples) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZovaColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      example.english,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      example.persian,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 15,
                        color: ZovaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (topic.tip != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZovaColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ZovaColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb,
                        color: ZovaColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        topic.tip!,
                        style: const TextStyle(
                          color: ZovaColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
