import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../core/widgets/vocabulary_card.dart';
import '../../data/models/translation_result.dart';
import '../../data/services/translation_service.dart';

/// My Words: the words the learner has bookmarked from the dictionary.
///
/// Bookmarks only store the word string; the current translation is resolved
/// on demand through the dynamic [TranslationService] (and served from cache
/// when offline).
class MyWordsScreen extends StatelessWidget {
  const MyWordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = context.watch<LanguageController>().settings;
    final savedWords = controller.progress.savedWordsFor(settings.learningLanguage);
    final languageCode = settings.contentLanguageCode;

    return Scaffold(
      appBar: AppBar(title: const TrText('My Words')),
      body: SafeArea(
        child: _SavedWordsList(
          key: ValueKey(savedWords),
          words: savedWords,
          wordsScope: settings.learningLanguage,
          languageCode: languageCode,
          controller: controller,
        ),
      ),
    );
  }
}

class _SavedWordsList extends StatefulWidget {
  const _SavedWordsList({
    super.key,
    required this.words,
    required this.wordsScope,
    required this.languageCode,
    required this.controller,
  });

  final List<String> words;

  /// Learning-language scope the saved words belong to (used to check Leitner
  /// membership in the same scope).
  final String wordsScope;
  final String languageCode;
  final AppController controller;

  @override
  State<_SavedWordsList> createState() => _SavedWordsListState();
}

class _SavedWordsListState extends State<_SavedWordsList> {
  final Map<String, TranslationResult> _results = {};
  final Set<String> _failed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _resolveWord(String word) async {
    try {
      final result = await TranslationService.instance.lookupAnySource(
        word: word,
        target: widget.languageCode,
      );
      if (!mounted) return;
      setState(() {
        if (result != null && !result.isEmpty) {
          _results[word] = result;
          _failed.remove(word);
        } else {
          _results.remove(word);
          _failed.add(word);
        }
      });
    } on TranslationException {
      if (!mounted) return;
      setState(() {
        _results.remove(word);
        _failed.add(word);
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    for (final word in widget.words) {
      await _resolveWord(word);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final entries = [for (final word in widget.words) _entryOf(word)];
    context.watch<UiTranslationController?>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        const TrText(
          'Words you saved',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: ZovaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _loading
              ? context.tr('Resolving translations…')
              : context.trTempl(
                  entries.length == 1
                      ? '{0} word · bookmark words from the dictionary to '
                          'keep them here.'
                      : '{0} words · bookmark words from the dictionary to '
                          'keep them here.',
                  [entries.length],
                ),
          style: const TextStyle(
            color: ZovaColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        if (entries.isNotEmpty && !_loading)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
            ),
            onPressed: () {
              for (final entry in entries) {
                widget.controller.addToLeitner(entry.word);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.trTempl(
                      'Added {0} words to your Leitner Box',
                      [entries.length],
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.style, size: 20),
            label: Text(context.tr('Add all to Leitner Box')),
          ),
        const SizedBox(height: 20),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          )
        else if (entries.isEmpty)
          const _EmptyState()
        else
          for (final entry in entries) ...[
            _WordCard(
              entry: entry,
              inLeitner: widget.controller.progress
                  .leitnerBoxesFor(widget.wordsScope)
                  .containsKey(entry.word),
              onRetry: () => _resolveWord(entry.word),
              onAddToLeitner: () {
                widget.controller.addToLeitner(entry.word);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.trTempl('Added "{0}" to Leitner', [
                        entry.word,
                      ]),
                    ),
                  ),
                );
              },
              onRemove: () {
                widget.controller.removeSavedWord(entry.word);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.trTempl('Removed "{0}" from My Words', [
                        entry.word,
                      ]),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  _WordEntry _entryOf(String word) {
    final result = _results[word];
    if (result != null) return _WordEntry(word, result);
    return _WordEntry(word, null, failed: _failed.contains(word));
  }
}

class _WordEntry {
  const _WordEntry(this.word, this.result, {this.failed = false});

  final String word;
  final TranslationResult? result;
  final bool failed;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.bookmark_add_outlined,
              color: ZovaColors.textSecondary, size: 36),
          SizedBox(height: 12),
          TrText(
            'No saved words yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ZovaColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          TrText(
            'Open any word in the Dictionary and tap the bookmark to save '
            'it here for quick revision.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZovaColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.entry,
    required this.inLeitner,
    required this.onRetry,
    required this.onAddToLeitner,
    required this.onRemove,
  });

  final _WordEntry entry;
  final bool inLeitner;
  final VoidCallback onRetry;
  final VoidCallback onAddToLeitner;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final result = entry.result;
    context.watch<UiTranslationController?>();

    return VocabularyCard(
      word: entry.word,
      gender: result?.gender,
      translation: entry.failed
          ? context.tr('Offline — tap to retry')
          : result?.translation,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.failed)
            IconButton(
              tooltip: context.tr('Retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              color: Colors.white70,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            tooltip: context.tr('Add to Leitner Box'),
            onPressed: inLeitner ? null : onAddToLeitner,
            icon: Icon(
              inLeitner ? Icons.style : Icons.style_outlined,
              size: 20,
              color:
                  inLeitner ? ZovaColors.primary : Colors.white.withValues(alpha: 0.7),
            ),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: context.tr('Remove from My Words'),
            onPressed: onRemove,
            icon: const Icon(Icons.bookmark_remove_outlined,
                size: 20, color: Colors.white70),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
