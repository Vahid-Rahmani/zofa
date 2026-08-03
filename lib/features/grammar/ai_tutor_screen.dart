import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/services/ai_tutor_service.dart';

/// Ask the AI tutor anything about the language being studied.
///
/// Answers come from the hosted model, are written in the learner's native
/// language and are cached on-device (a repeat question is instant and works
/// offline). The answer area includes a few suggested prompts to make common
/// grammar questions one tap away.
class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key, required this.sessionContext});

  /// What the learner is currently studying (e.g. "Grammar"), passed to the
  /// model so the answer can be contextual.
  final String sessionContext;

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final TextEditingController _controller = TextEditingController();
  AiTutorReply? _reply;
  String? _error;
  bool _loading = false;
  bool _asked = false;

  static const List<String> _suggestions = [
    'Explain articles (a/an/the)',
    'What is the difference between few and a few?',
    'How do I build a question?',
    'Present simple vs present continuous',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _loading) return;
    if (preset != null) _controller.text = preset;

    final language = context.read<LanguageController>().settings;
    setState(() {
      _loading = true;
      _error = null;
      _asked = true;
      _reply = null;
    });
    try {
      final reply = await AiTutorService.instance.askTutor(
        question: question,
        source: language.learningLanguage,
        target: language.contentLanguageCode,
        sessionContext: widget.sessionContext,
      );
      if (!mounted) return;
      setState(() {
        _reply = reply;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _error = context.tr(
          'Couldn\'t reach the AI tutor. Check your connection and try again.',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    final configured = AiTutorService.instance.isConfigured;

    return Scaffold(
      appBar: AppBar(
        title: const TrText('Ask the AI tutor'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ZovaColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: ZovaColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: TrText(
                          'A personal tutor for anything you\'re stuck on — '
                          'grammar rules, word choices, or a sentence you '
                          'don\'t understand. Answers are cached on your '
                          'device.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: ZovaColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (!configured)
                    const _Notice(
                      icon: Icons.info_outline,
                      message:
                          'The AI tutor is not configured on this build. Add '
                          'ZOVA_AI_API_KEY via --dart-define-from-file=.env to '
                          'enable AI answers.',
                    )
                  else if (!_asked) ...[
                    const TrText(
                      'Try asking',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ZovaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final suggestion in _suggestions) ...[
                      ActionChip(
                        label: Text(suggestion),
                        onPressed: () => _send(suggestion),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ] else if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  else if (_error != null)
                    _Notice(icon: Icons.wifi_off, message: _error!)
                  else if (_reply != null && !_reply!.isEmpty)
                    _AnswerCard(
                      reply: _reply!,
                      rtl: context.read<LanguageController>().settings.isRtlUi
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    )
                  else
                    const _Notice(
                      icon: Icons.error_outline,
                      message:
                          'The tutor couldn\'t answer that. Try rephrasing your '
                          'question.',
                    ),
                ],
              ),
            ),
            if (configured)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: context.tr('Ask about grammar, words…'),
                            filled: true,
                            fillColor: ZovaColors.surfaceRaised,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        onPressed: _loading ? null : _send,
                        icon: const Icon(Icons.send),
                        style: IconButton.styleFrom(
                          backgroundColor: ZovaColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.reply, required this.rtl});

  final AiTutorReply reply;
  final TextDirection rtl;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZovaColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: ZovaColors.primary),
              const SizedBox(width: 6),
              Text(
                context.tr('AI tutor'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.primary,
                ),
              ),
              if (reply.fromCache) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ZovaColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('Cached'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ZovaColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            reply.answer,
            textDirection: rtl,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: ZovaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ZovaColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: ZovaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
