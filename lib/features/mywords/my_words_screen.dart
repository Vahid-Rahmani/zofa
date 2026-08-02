import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/dictionary_entry.dart';
import '../../data/services/dictionary.dart';
import '../../data/services/dictionary_service.dart';

/// My Words: the words the learner has bookmarked from the dictionary.
class MyWordsScreen extends StatelessWidget {
  const MyWordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final savedWords = controller.progress.savedWords;

    return Scaffold(
      appBar: AppBar(title: const Text('My Words')),
      body: SafeArea(
        child: FutureBuilder<DictionaryService>(
          future: Dictionary.service,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final dict = snapshot.data!;
            final entries = [
              for (final word in savedWords)
                if (dict.lookup(word) != null) dict.lookup(word)!,
            ];

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
                  '${entries.length} ${entries.length == 1 ? 'word' : 'words'} '
                  '· bookmark words from the dictionary to keep them here.',
                  style: const TextStyle(
                    color: ZovaColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (entries.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    onPressed: () {
                      for (final entry in entries) {
                        controller.addToLeitner(entry.word);
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
                if (entries.isEmpty)
                  const _EmptyState()
                else
                  for (final entry in entries) ...[
                    _WordCard(
                      entry: entry,
                      inLeitner: controller.progress.leitnerBoxes
                          .containsKey(entry.word),
                      onAddToLeitner: () {
                        controller.addToLeitner(entry.word);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added "${entry.word}" to Leitner')),
                        );
                      },
                      onRemove: () {
                        controller.removeSavedWord(entry.word);
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
          },
        ),
      ),
    );
  }
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
    required this.onAddToLeitner,
    required this.onRemove,
  });

  final DictionaryEntry entry;
  final bool inLeitner;
  final VoidCallback onAddToLeitner;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final levelColor = switch (entry.level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      _ => ZovaColors.warning,
    };

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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        entry.level,
                        style: TextStyle(
                          color: levelColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.translation,
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
