import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../core/widgets/vocabulary_card.dart';
import '../../data/services/english_frequency.dart';
import '../../data/services/english_grammar.dart';
import 'vocabulary_themes.dart';
import 'word_study_screen.dart';

/// All the words in one CEFR level (e.g. `B1`), organised into themed
/// categories (Food & Drinks, Travel, Family, ...) with part-of-speech
/// fallback buckets (Verbs, Nouns, ...).
///
/// The level opens on a Duolingo-style grid of category cards — icon, word
/// count and a "learned" progress bar. Tapping a card drills into that single
/// theme's words (each word belongs to exactly one category), rendered lazily
/// so levels with tens of thousands of words stay fast. Every word is
/// live-translated into the learner's native language; tapping it opens the
/// dictionary-style [WordStudyScreen].
class LevelWordsScreen extends StatefulWidget {
  const LevelWordsScreen({super.key, required this.level});

  final String level;

  @override
  State<LevelWordsScreen> createState() => _LevelWordsScreenState();
}

class _LevelWordsScreenState extends State<LevelWordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// The opened category, or `null` while showing the category grid.
  VocabularyCategory? _selected;

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
        builder: (_) => WordStudyScreen(
          word: word,
          level: widget.level,
          rank: rank,
        ),
      ),
    );
  }

  void _selectCategory(VocabularyCategory category) {
    setState(() {
      _selected = category;
      _query = '';
      _searchController.clear();
    });
  }

  void _backToCategories() {
    setState(() {
      _selected = null;
      _query = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            selected == null
                ? '${widget.level} · ${_levelLabel(widget.level)}'
                : selected.title,
          ),
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        leading: selected == null
            ? null
            : IconButton(
                tooltip: context.tr('All categories'),
                onPressed: _backToCategories,
                icon: const Icon(Icons.arrow_back),
              ),
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
            final scope =
                context.read<LanguageController>().settings.learningLanguage;
            final progress = context.watch<AppController>().progress;
            final learned = <String>{
              ...progress.savedWordsFor(scope),
              ...progress.learningFor(scope).keys,
            };

            final selected = _selected;
            if (selected == null) {
              return _CategoriesView(
                words: words,
                grammar: grammar,
                learned: learned,
                query: _query,
                searchController: _searchController,
                onQueryChanged: (value) => setState(() => _query = value),
                onClearQuery: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                onCategoryTap: _selectCategory,
              );
            }
            final categoryWords = words
                .where((w) =>
                    categoryFor(w, grammar.sectionOf(w)).id == selected.id)
                .toList(growable: false);
            return _CategoryWordsView(
              words: categoryWords,
              list: list,
              grammar: grammar,
              showRanks: _query.trim().isEmpty,
              query: _query,
              searchController: _searchController,
              onQueryChanged: (value) => setState(() => _query = value),
              onWordTap: _openWord,
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

/// The category grid (default view): one rich card per theme / POS bucket with
/// a word count and a "learned" progress bar.
class _CategoriesView extends StatelessWidget {
  const _CategoriesView({
    required this.words,
    required this.grammar,
    required this.learned,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onCategoryTap,
  });

  final List<String> words;
  final EnglishGrammar grammar;
  final Set<String> learned;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<VocabularyCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final categories = <VocabularyCategory, int>{};
    final learnedCounts = <VocabularyCategory, int>{};
    for (final word in words) {
      final category = categoryFor(word, grammar.sectionOf(word));
      categories.update(category, (count) => count + 1, ifAbsent: () => 1);
      if (learned.contains(word)) {
        learnedCounts.update(category, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    final q = query.trim().toLowerCase();
    final visible = [
      for (final entry in categories.entries)
        if (entry.value > 0 && (q.isEmpty || entry.key.title.toLowerCase().contains(q)))
          (category: entry.key, count: entry.value),
    ]..sort((a, b) => b.count.compareTo(a.count));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Text(
            context.trTempl(
              '{0} words · choose a theme to focus on',
              [words.length],
            ),
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
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: context.tr('Find a theme…'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClearQuery,
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
                    context.trTempl('No themes match "{0}".', [query]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ZovaColors.textSecondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 138,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return _CategoryCard(
                      category: item.category,
                      count: item.count,
                      learned: learnedCounts[item.category] ?? 0,
                      onTap: () => onCategoryTap(item.category),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A single category card: colored icon tile, title, word count and the
/// fraction of the theme's words the learner has already "learned".
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.learned,
    required this.onTap,
  });

  final VocabularyCategory category;
  final int count;
  final int learned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = count == 0 ? 0.0 : learned / count;
    final accent = category.color;
    final dark = Color.lerp(accent, Colors.black, 0.35)!;
    return Material(
      color: ZovaColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.16),
                ZovaColors.surface,
              ],
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, dark],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(category.icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              TrText(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor:
                            accent.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.trTempl('{0} learned', [learned]),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ZovaColors.textSecondary,
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

/// The words of one category, with a search field and lazy word cards.
class _CategoryWordsView extends StatelessWidget {
  const _CategoryWordsView({
    required this.words,
    required this.list,
    required this.grammar,
    required this.showRanks,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onWordTap,
  });

  final List<String> words;
  final EnglishFrequencyList list;
  final EnglishGrammar grammar;
  final bool showRanks;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final void Function(String word, int? rank) onWordTap;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty
        ? words
        : words.where((w) => w.contains(q)).toList(growable: false);

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
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: context.tr('Filter words…'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onQueryChanged('');
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
                    context.trTempl('No words match "{0}".', [query]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ZovaColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final word = visible[index];
                    final rank = showRanks ? list.rankOf(word) : null;
                    return VocabularyCard(
                      word: word,
                      liveTranslate: true,
                      gender: grammar.partOfSpeech(word) == null
                          ? null
                          : context
                              .tr(grammar.partOfSpeech(word)!),
                      level: rank != null ? '#$rank' : null,
                      onTap: () => onWordTap(word, rank),
                    );
                  },
                ),
        ),
      ],
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
