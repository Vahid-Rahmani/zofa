import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
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
    final savedWords = controller.progress.savedWords;
    final languageCode =
        context.watch<LanguageController>().settings.translationLanguage.code;

    return Scaffold(
      appBar: AppBar(title: const Text('My Words')),
      body: SafeArea(
        child: _SavedWordsList(
          key: ValueKey(savedWords),
          words: savedWords,
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
    required this.languageCode,
    required this.controller,
  });

  final List<String> words;
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        const Text(
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
              ? 'Resolving translations…'
              : '${entries.length} ${entries.length == 1 ? 'word' : 'words'} · '
                  'bookmark words from the dictionary to keep them here.',
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
                    'Added ${entries.length} words to your Leitner Box',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.style, size: 20),
            label: const Text('Add all to Leitner Box'),
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
              inLeitner: widget.controller.progress.leitnerBoxes
                  .containsKey(entry.word),
              onRetry: () => _resolveWord(entry.word),
              onAddToLeitner: () {
                widget.controller.addToLeitner(entry.word);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added "${entry.word}" to Leitner')),
                );
              },
              onRemove: () {
                widget.controller.removeSavedWord(entry.word);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed "${entry.word}" from My Words'),
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
          Text(
            'No saved words yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ZovaColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
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
    final rtl = result?.isRtl ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.word,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                    ),
                    if (result?.glossLine != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        result!.glossLine!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: ZovaColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (entry.failed)
                  Row(
                    children: [
                      const Icon(Icons.cloud_off,
                          size: 14, color: ZovaColors.textSecondary),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Offline — tap to retry',
                          style: TextStyle(
                            fontSize: 13,
                            color: ZovaColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Retry',
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  )
                else
                  Text(
                    result?.translation ?? '',
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ZovaColors.secondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add to Leitner Box',
            onPressed: inLeitner ? null : onAddToLeitner,
            icon: Icon(
              inLeitner ? Icons.style : Icons.style_outlined,
              color: inLeitner ? ZovaColors.primary : ZovaColors.textSecondary,
            ),
          ),
          IconButton(
            tooltip: 'Remove from My Words',
            onPressed: onRemove,
            icon: const Icon(Icons.bookmark_remove_outlined,
                color: ZovaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
