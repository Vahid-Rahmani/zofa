import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/services/english_frequency.dart';
import '../../data/services/translation_service.dart';
import '../dictionary/dictionary_screen.dart' show EntryDetailScreen;

/// All the words in one CEFR level (e.g. `B1`), lazily rendered so levels with
/// tens of thousands of words stay fast. Tapping a word looks it up live
/// through the dynamic [TranslationService] and opens the shared
/// [EntryDetailScreen] for saving / Leitner actions.
class LevelWordsScreen extends StatefulWidget {
  const LevelWordsScreen({super.key, required this.level});

  final String level;

  @override
  State<LevelWordsScreen> createState() => _LevelWordsScreenState();
}

class _LevelWordsScreenState extends State<LevelWordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openWord(String word) async {
    final languageCode =
        context.read<LanguageController>().settings.nativeLanguage;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final result = await TranslationService.instance.lookup(
        word: word,
        source: 'en',
        target: languageCode,
      );
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => EntryDetailScreen(result: result),
        ),
      );
    } on TranslationException {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.tr('Offline — couldn’t translate this word.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('${widget.level} · ${_levelLabel(widget.level)}'),
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<EnglishFrequencyList>(
          future: EnglishFrequencyList.service,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.hasError) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              );
            }
            final list = snapshot.data!;
            final words = list.wordsForLevel(widget.level);
            final query = _query.trim().toLowerCase();
            final visible = query.isEmpty
                ? words
                : words
                    .where((w) => w.contains(query))
                    .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                  child: Text(
                    context.trTempl('{0} words', [words.length]),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ZovaColors.textSecondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: context.tr('Filter words…'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: ZovaColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            _query.isEmpty
                                ? context.tr('No words in this level yet.')
                                : context.trTempl(
                                    'No words match "{0}".', [_query]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ZovaColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final word = visible[index];
                            final rank = query.isEmpty
                                ? (list.rankOf(word) ?? 0)
                                : null;
                            return _WordTile(
                              word: word,
                              rank: rank,
                              onTap: () => _openWord(word),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.rank,
    required this.onTap,
  });

  final String word;
  final int? rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (rank != null) ...[
                Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ZovaColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  word,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ZovaColors.textPrimary,
                  ),
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
