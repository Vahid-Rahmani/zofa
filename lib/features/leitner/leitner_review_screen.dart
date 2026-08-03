import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/models/translation_result.dart';
import '../gamification/hearts_bar.dart';

/// Flashcard review session for one Leitner box.
///
/// The word is shown first; tapping the card reveals the meaning. "Knew it"
/// promotes the word to the next box, "Still learning" sends it back to box 1.
class LeitnerReviewScreen extends StatefulWidget {
  const LeitnerReviewScreen({
    super.key,
    required this.box,
    required this.words,
  });

  final int box;
  final List<TranslationResult> words;

  @override
  State<LeitnerReviewScreen> createState() => _LeitnerReviewScreenState();
}

class _LeitnerReviewScreenState extends State<LeitnerReviewScreen> {
  int _index = 0;
  bool _revealed = false;
  int _known = 0;
  int _relearned = 0;

  TranslationResult get _current => widget.words[_index];

  bool get _isDone => _index >= widget.words.length;

  void _answer({required bool knew}) {
    final controller = context.read<AppController>();
    controller.reviewLeitnerCard(_current.word, knew: knew);
    if (knew) {
      _known++;
    } else {
      _relearned++;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.trTempl('Box {0}', [widget.box]),
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: HeartsBar()),
          ),
        ],
      ),
      body: SafeArea(
        child: _isDone
            ? _Summary(
                known: _known,
                relearned: _relearned,
                box: widget.box,
                onDone: () => Navigator.of(context).pop(),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.trTempl('Card {0} of {1}', [
                        _index + 1,
                        widget.words.length,
                      ]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ZovaColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _index / widget.words.length,
                        minHeight: 8,
                        backgroundColor: ZovaColors.surfaceRaised,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _Flashcard(
                        entry: _current,
                        revealed: _revealed,
                        onTap: () => setState(() => _revealed = !_revealed),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!_revealed)
                      const TrText(
                        'Tap the card to reveal the meaning',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ZovaColors.textSecondary),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ZovaColors.error,
                                side: const BorderSide(color: ZovaColors.error),
                                minimumSize: const Size(0, 54),
                              ),
                              onPressed: () => _answer(knew: false),
                              child: Text(context.tr('Still learning')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ZovaColors.success,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 54),
                              ),
                              onPressed: () => _answer(knew: true),
                              child: Text(context.tr('Knew it')),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Flashcard extends StatelessWidget {
  const _Flashcard({
    required this.entry,
    required this.revealed,
    required this.onTap,
  });

  final TranslationResult entry;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: double.infinity,
        decoration: BoxDecoration(
          color: ZovaColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: revealed
                ? ZovaColors.primary.withValues(alpha: 0.6)
                : ZovaColors.surfaceRaised,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: revealed ? _meaning(context) : _word(context),
        ),
      ),
    );
  }

  Widget _word(BuildContext context) {
    final rtl = entry.isRtl;
    return Column(
      key: const ValueKey('word'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.help_outline, color: ZovaColors.textSecondary, size: 32),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            entry.word,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: ZovaColors.textPrimary,
            ),
          ),
        ),
        if (entry.glossLine != null) ...[
          const SizedBox(height: 8),
          Text(
            entry.glossLine!,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              fontSize: 16,
              color: ZovaColors.secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _meaning(BuildContext context) {
    final code =
        context.watch<LanguageController>().settings.contentLanguageCode;
    final rtl = entry.isRtl || code == 'fa';
    return SingleChildScrollView(
      key: const ValueKey('meaning'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entry.translation,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ZovaColors.secondary,
            ),
          ),
          const SizedBox(height: 18),
          const TrText(
            'Example',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.example == null ? '—' : '“${entry.example}”',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              color: ZovaColors.textPrimary,
            ),
          ),
          if (entry.exampleTranslation != null) ...[
            const SizedBox(height: 6),
            Text(
              entry.exampleTranslation!,
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: ZovaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.known,
    required this.relearned,
    required this.box,
    required this.onDone,
  });

  final int known;
  final int relearned;
  final int box;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final total = known + relearned;
    final nextBox = box < 5 ? box + 1 : 5;
    context.watch<UiTranslationController?>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events,
              color: ZovaColors.warning, size: 64),
          const SizedBox(height: 16),
          const TrText(
            'Session complete!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: ZovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.trTempl('You reviewed {0} words in box {1}.', [
              total,
              box,
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZovaColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ZovaColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _SummaryStat(
                  label: 'Knew it',
                  value: '$known',
                  color: ZovaColors.success,
                ),
                const SizedBox(width: 14),
                _SummaryStat(
                  label: 'Relearned',
                  value: '$relearned',
                  color: ZovaColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            known == 0 && relearned > 0
                ? context.tr(
                    'Keep practicing — every word you review moves forward.')
                : box < 5 && known > 0
                    ? context.trTempl(
                        'Words you knew moved to box {0}.',
                        [nextBox],
                      )
                    : context.tr(
                        'You are at the top box. Review less often, remember '
                        'more.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZovaColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: ZovaColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('Done')),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(label),
            style: const TextStyle(color: ZovaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
