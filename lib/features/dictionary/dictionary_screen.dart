import 'package:flutter/material.dart';

import '../../core/theme/zova_colors.dart';
import '../../data/models/dictionary_entry.dart';
import '../../data/services/dictionary.dart';

/// The Dictionary tab: searchable English -> Persian dictionary with hundreds
/// of entries, each carrying an example sentence and a proficiency level.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Selected CEFR level; `null` means all levels.
  String? _level;

  /// Whether the German dictionary is shown instead of the English one.
  bool _isGerman = false;

  List<DictionaryEntry> get _all => _isGerman ? GermanDictionary.all : Dictionary.all;

  List<DictionaryEntry> get _results {
    final base = _query.trim().isEmpty
        ? _all
        : _isGerman
            ? GermanDictionary.search(_query)
            : Dictionary.search(_query);
    if (_level == null) return base;
    return base.where((e) => e.level == _level).toList();
  }

  int _countFor(String level) =>
      (_isGerman ? GermanDictionary.byLevel(level) : Dictionary.byLevel(level))
          .length;

  int get _wordCount => _isGerman ? GermanDictionary.wordCount : Dictionary.wordCount;

  String get _languageLabel => _isGerman ? 'German → Persian' : 'English → Persian';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dictionary',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_wordCount words · $_languageLabel',
                    style: const TextStyle(color: ZovaColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('English'),
                        icon: Icon(Icons.translate, size: 18),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('German'),
                        icon: Icon(Icons.translate, size: 18),
                      ),
                    ],
                    selected: {_isGerman},
                    onSelectionChanged: (selection) =>
                        setState(() => _isGerman = selection.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? ZovaColors.primary
                            : ZovaColors.surface,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : ZovaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search a word or meaning…',
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _LevelFilterChip(
                    label: 'All',
                    count: _wordCount,
                    selected: _level == null,
                    onTap: () => setState(() => _level = null),
                  ),
                  const SizedBox(width: 8),
                  _LevelFilterChip(
                    label: 'A1',
                    count: _countFor('A1'),
                    selected: _level == 'A1',
                    onTap: () => setState(() => _level = 'A1'),
                  ),
                  const SizedBox(width: 8),
                  _LevelFilterChip(
                    label: 'A2',
                    count: _countFor('A2'),
                    selected: _level == 'A2',
                    onTap: () => setState(() => _level = 'A2'),
                  ),
                  const SizedBox(width: 8),
                  _LevelFilterChip(
                    label: 'B1',
                    count: _countFor('B1'),
                    selected: _level == 'B1',
                    onTap: () => setState(() => _level = 'B1'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${results.length} result${results.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: ZovaColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'No words match your search.',
                        style: TextStyle(color: ZovaColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        return _EntryCard(
                          entry: entry,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => EntryDetailScreen(entry: entry),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelFilterChip extends StatelessWidget {
  const _LevelFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      'B1' => ZovaColors.warning,
      _ => ZovaColors.textSecondary,
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : ZovaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : ZovaColors.textSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : ZovaColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.9)
                    : ZovaColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final DictionaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.word,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: ZovaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.partOfSpeech,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: ZovaColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.translation,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ZovaColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              _LevelChip(level: entry.level),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: ZovaColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small CEFR badge used on cards and in the detail view.
class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'A1' => ZovaColors.success,
      'A2' => ZovaColors.primary,
      _ => ZovaColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Full-screen detail for a single dictionary entry.
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({super.key, required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.word, style: const TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.word,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                      if (entry.phonetic != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.phonetic!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: ZovaColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _LevelChip(level: entry.level),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.partOfSpeech,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ZovaColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                entry.translation,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Example',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '“${entry.example}”',
              style: const TextStyle(
                fontSize: 17,
                height: 1.5,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.exampleTranslation,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Learn it in a course',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This word appears in the A1-A2-B1 course lessons, so you can '
              'practice it with flashcards, matching games and quizzes.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: ZovaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
