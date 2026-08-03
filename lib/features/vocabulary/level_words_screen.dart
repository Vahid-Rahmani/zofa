import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/services/english_frequency.dart';
import '../../data/services/english_grammar.dart';
import 'word_study_screen.dart';

/// All the words in one CEFR level (e.g. `B1`), lazily rendered so levels with
/// tens of thousands of words stay fast. Words are grouped into part-of-speech
/// sections (Verbs, Nouns, Adjectives, Adverbs, Other words). Tapping a word
/// opens the dictionary-style [WordStudyScreen], which translates it live into
/// the learner's native language and shows verb forms and examples.
class LevelWordsScreen extends StatefulWidget {
  const LevelWordsScreen({super.key, required this.level});

  final String level;

  @override
  State<LevelWordsScreen> createState() => _LevelWordsScreenState();
}

class _LevelWordsScreenState extends State<LevelWordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// Created once so the [FutureBuilder] below resubscribes to the same
  /// completed future instead of an infinite stream of fresh futures.
  late final Future<(EnglishFrequencyList, EnglishGrammar)> _dataFuture =
      _loadData();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openWord(String word, int? rank) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WordStudyScreen(word: word, level: widget.level, rank: rank),
      ),
    );
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
        child: FutureBuilder<(EnglishFrequencyList, EnglishGrammar)>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.hasError) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              );
            }
            final list = snapshot.data!.$1;
            final grammar = snapshot.data!.$2;
            final words = list.wordsForLevel(widget.level);
            final query = _query.trim().toLowerCase();
            final visible = query.isEmpty
                ? words
                : words.where((w) => w.contains(query)).toList(growable: false);

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
                      : _GroupedWordList(
                          visible: visible,
                          grammar: grammar,
                          rankOf: list.rankOf,
                          showRanks: query.isEmpty,
                          onWordTap: _openWord,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// `Future.wait` misbehaves with Flutter's [SynchronousFuture] (seeded
  /// services complete with an empty list), so await the two services
  /// sequentially instead.
  Future<(EnglishFrequencyList, EnglishGrammar)> _loadData() async {
    final list = await EnglishFrequencyList.service;
    final grammar = await EnglishGrammar.service;
    return (list, grammar);
  }
}

/// Lazily renders the visible words grouped into part-of-speech sections.
class _GroupedWordList extends StatelessWidget {
  const _GroupedWordList({
    required this.visible,
    required this.grammar,
    required this.rankOf,
    required this.showRanks,
    required this.onWordTap,
  });

  final List<String> visible;
  final EnglishGrammar grammar;
  final int? Function(String word) rankOf;
  final bool showRanks;
  final void Function(String word, int? rank) onWordTap;

  /// Section order: the major content-word groups first, then everything else.
  static const List<EnglishSection> _order = [
    EnglishSection.verb,
    EnglishSection.noun,
    EnglishSection.adjective,
    EnglishSection.adverb,
    EnglishSection.other,
  ];

  @override
  Widget build(BuildContext context) {
    final sections = <EnglishSection, List<String>>{
      for (final section in _order) section: <String>[],
    };
    for (final word in visible) {
      sections[grammar.sectionOf(word)]!.add(word);
    }
    final rows = <_Row>[];
    for (final section in _order) {
      final words = sections[section]!;
      if (words.isEmpty) continue;
      rows.add(_Row.header(section, words.length));
      rows.addAll(words.map(_Row.word));
    }
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.isHeader) {
          return _SectionHeader(
            section: row.section!,
            count: row.count!,
          );
        }
        final word = row.word!;
        return _WordTile(
          word: word,
          rank: showRanks ? rankOf(word) : null,
          posLabel: grammar.partOfSpeech(word),
          onTap: () => onWordTap(word, showRanks ? rankOf(word) : null),
        );
      },
    );
  }
}

class _Row {
  const _Row.header(this.section, this.count)
      : word = null,
        isHeader = true;
  const _Row.word(this.word)
      : section = null,
        count = null,
        isHeader = false;

  final EnglishSection? section;
  final int? count;
  final String? word;
  final bool isHeader;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.count});

  final EnglishSection section;
  final int count;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    final label = switch (section) {
      EnglishSection.verb => 'Verbs',
      EnglishSection.noun => 'Nouns',
      EnglishSection.adjective => 'Adjectives',
      EnglishSection.adverb => 'Adverbs',
      EnglishSection.other => 'Other words',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Text(
            context.tr(label),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ZovaColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: ZovaColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ZovaColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.rank,
    required this.posLabel,
    required this.onTap,
  });

  final String word;
  final int? rank;
  final String? posLabel;
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
              if (posLabel != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZovaColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr(posLabel!),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ZovaColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
