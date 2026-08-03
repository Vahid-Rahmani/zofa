import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/services/english_frequency.dart';
import 'level_words_screen.dart';

/// The Vocabulary tab: the 50,000 most frequent English words, organised into
/// CEFR levels (A1 → C2) so learners can study exactly the difficulty they
/// are ready for.
///
/// Word lists are the bundled frequency-ranked `english_top_50k` asset; each
/// word's translation, definition and example are produced live by the dynamic
/// [TranslationService] bridge when the learner opens it (and cached on-device
/// for offline review).
class VocabularyScreen extends StatelessWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<EnglishFrequencyList>(
          future: EnglishFrequencyList.service,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.hasError) {
              return const _LoadingState();
            }
            final list = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                const TrText(
                  'Vocabulary',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                TrText(
                  context.trTempl(
                    'The {0} most frequent English words, organised by level.',
                    [list.length],
                  ),
                  style: const TextStyle(
                    color: ZovaColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                for (final band in kEnglishCefrBands) ...[
                  _LevelCard(
                    band: band,
                    count: list.countForLevel(band.level),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LevelWordsScreen(level: band.level),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.band,
    required this.count,
    required this.onTap,
  });

  final CefrLevelBand band;
  final int count;
  final VoidCallback onTap;

  Color get _color => _levelColor(band.level);

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    final label = _levelLabel(band.level);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  band.level,
                  style: TextStyle(
                    color: _color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(label),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.trTempl('{0} words', [count]),
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

/// Long CEFR level names shown next to each band (e.g. "Beginner").
String _levelLabel(String level) => switch (level) {
      'A1' => 'Beginner',
      'A2' => 'Elementary',
      'B1' => 'Intermediate',
      'B2' => 'Upper-intermediate',
      'C1' => 'Advanced',
      'C2' => 'Proficient',
      _ => level,
    };

/// Accent colour for a CEFR level card.
Color _levelColor(String level) => switch (level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      'B1' => ZovaColors.warning,
      'B2' => ZovaColors.secondary,
      'C1' => ZovaColors.info,
      'C2' => ZovaColors.gold,
      _ => ZovaColors.primary,
    };

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 3),
    );
  }
}
