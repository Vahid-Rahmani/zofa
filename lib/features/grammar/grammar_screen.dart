import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/content_text.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/models/ai_grammar_explanation.dart';
import '../../data/models/grammar_topic.dart';
import '../../data/services/ai_tutor_service.dart';
import '../../data/services/grammar_content.dart';
import 'ai_tutor_screen.dart';

/// Grammar hub: a curated list of English grammar points, grouped by level,
/// plus an AI tutor entry for asking your own questions.
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
            const SizedBox(height: 18),
            _AskAiCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AiTutorScreen(
                      sessionContext: 'Grammar',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
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

/// Entry point to the AI tutor: ask your own grammar questions.
class _AskAiCard extends StatelessWidget {
  const _AskAiCard({required this.onTap});

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
                child: const Icon(
                  Icons.auto_awesome,
                  color: ZovaColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'Ask the AI tutor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    TrText(
                      'Ask your own question about any grammar rule.',
                      style: TextStyle(
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
class GrammarDetailScreen extends StatefulWidget {
  const GrammarDetailScreen({super.key, required this.topic});

  final GrammarTopic topic;

  @override
  State<GrammarDetailScreen> createState() => _GrammarDetailScreenState();
}

class _GrammarDetailScreenState extends State<GrammarDetailScreen> {
  AiGrammarExplanation? _aiExplanation;
  String? _aiError;
  bool _aiLoading = false;

  GrammarTopic get topic => widget.topic;

  @override
  void initState() {
    super.initState();
    if (AiTutorService.instance.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _explainWithAi());
    }
  }

  Future<void> _explainWithAi() async {
    final language = context.read<LanguageController>().settings;
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final explanation = await AiTutorService.instance.explainGrammar(
        topicOrQuestion: '${topic.title} — ${topic.summary}',
        source: 'en',
        target: language.contentLanguageCode,
      );
      if (!mounted) return;
      setState(() {
        _aiExplanation = explanation;
        _aiLoading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _aiError = context.tr(
          'Couldn\'t reach the AI tutor. Check your connection and try again.',
        );
        _aiLoading = false;
      });
    }
  }

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
                      _ContentString(
                        topic.title,
                        persian: topic.faTitle,
                        style: const TextStyle(
                          color: ZovaColors.textSecondary,
                        ),
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
            _ContentString(
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
                    _ContentString(
                      example.english,
                      persian: example.persian,
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
                      child: _ContentString(
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
            const SizedBox(height: 26),
            const Divider(height: 1, color: ZovaColors.surfaceRaised),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: ZovaColors.primary, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: TrText(
                    'Explain this with the AI tutor',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                ),
                if (AiTutorService.instance.isConfigured)
                  TextButton.icon(
                    onPressed: _aiLoading ? null : _explainWithAi,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                      context
                          .tr(_aiExplanation != null ? 'Refresh' : 'Explain'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_aiLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
              )
            else if (_aiError != null)
              _AiNotice(
                icon: Icons.wifi_off,
                message: _aiError!,
                onRetry: _explainWithAi,
              )
            else if (_aiExplanation != null)
              _AiExplanationCard(
                explanation: _aiExplanation!,
                rtl: context.read<LanguageController>().settings.isRtlUi
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              )
            else if (!AiTutorService.instance.isConfigured)
              const _AiNotice(
                icon: Icons.info_outline,
                message:
                    'AI explanations are not configured on this build. Add '
                    'ZOVA_AI_API_KEY via --dart-define-from-file=.env to enable '
                    'them.',
              )
            else
              const TrText(
                'Get a beginner-friendly explanation of this rule in your '
                'language.',
                style: TextStyle(
                  fontSize: 13,
                  color: ZovaColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The AI-generated explanation of a grammar topic.
class _AiExplanationCard extends StatelessWidget {
  const _AiExplanationCard({required this.explanation, required this.rtl});

  final AiGrammarExplanation explanation;
  final TextDirection rtl;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZovaColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (explanation.summary != null) ...[
            Text(
              explanation.summary!,
              textDirection: rtl,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ZovaColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (explanation.explanation != null) ...[
            Text(
              explanation.explanation!,
              textDirection: rtl,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: ZovaColors.textPrimary,
              ),
            ),
          ],
          if (explanation.examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final example in explanation.examples) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZovaColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      example.sentence,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    if (example.translation.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        example.translation,
                        textDirection: rtl,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ZovaColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (explanation.tip != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb,
                    color: ZovaColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    explanation.tip!,
                    textDirection: rtl,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AiNotice extends StatelessWidget {
  const _AiNotice({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZovaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ZovaColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: ZovaColors.textSecondary,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(context.tr('Retry')),
            ),
        ],
      ),
    );
  }
}

/// Grammar content translated into the learner's language of study: the
/// bundled Persian copy when the study language is Persian (offline-ready,
/// accurate), otherwise a live translation via [ContentText].
class _ContentString extends StatelessWidget {
  const _ContentString(
    this.english, {
    this.persian,
    this.style,
  });

  final String english;
  final String? persian;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final code =
        context.read<LanguageController>().settings.contentLanguageCode;
    if (code == 'fa' && persian != null && persian!.isNotEmpty) {
      return Text(
        persian!,
        textDirection: TextDirection.rtl,
        style: style,
      );
    }
    return ContentText(english, style: style);
  }
}
