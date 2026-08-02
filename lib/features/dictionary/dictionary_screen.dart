import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/dictionary_entry.dart';
import '../../data/services/dictionary.dart';
import '../../data/services/dictionary_service.dart';

/// The Dictionary tab: searchable English/German -> Persian dictionary backed
/// by the indexed [DictionaryService]. Searches are debounced and paginated so
/// the UI stays smooth even with hundreds of thousands of entries, and results
/// scroll infinitely while filters (level, part of speech, topic) narrow them.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  /// Whether the German dictionary is shown instead of the English one.
  bool _isGerman = false;

  late final Future<DictionaryService> _english = Dictionary.service;
  late final Future<DictionaryService> _german = GermanDictionary.service;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageController>();
    final translationLanguage = language.settings.translationLanguage;
    final future = _isGerman ? _german : _english;
    return FutureBuilder<DictionaryService>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _DictionaryBody(
          key: ValueKey(_isGerman),
          dict: snapshot.data!,
          languageLabel:
              '${_isGerman ? 'German' : 'English'} → ${translationLanguage.label}',
          isGerman: _isGerman,
          onLanguageChanged: (value) => setState(() => _isGerman = value),
        );
      },
    );
  }
}

/// Stateful search/filter/pagination surface for one loaded dictionary.
class _DictionaryBody extends StatefulWidget {
  const _DictionaryBody({
    super.key,
    required this.dict,
    required this.languageLabel,
    required this.isGerman,
    required this.onLanguageChanged,
  });

  final DictionaryService dict;
  final String languageLabel;
  final bool isGerman;
  final ValueChanged<bool> onLanguageChanged;

  @override
  State<_DictionaryBody> createState() => _DictionaryBodyState();
}

class _DictionaryBodyState extends State<_DictionaryBody> {
  static const int _pageSize = 40;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String _query = '';

  /// Selected CEFR level; `null` means all levels.
  String? _level;

  /// Selected part of speech; `null` means all.
  String? _pos;

  /// Selected topic / free-form tag; `null` means all.
  String? _tag;

  List<DictionaryEntry> _results = const [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final initial = widget.dict.searchPaged(_currentQuery(offset: 0));
    _results = initial.items;
    _total = initial.total;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  DictionaryQuery _currentQuery({required int offset}) => DictionaryQuery(
        query: _query,
        levels: _level == null ? const [] : [_level!],
        partsOfSpeech: _pos == null ? const [] : [_pos!],
        tags: _tag == null ? const [] : [_tag!],
        offset: offset,
        limit: _pageSize,
      );

  void _reload() {
    final result = widget.dict.searchPaged(_currentQuery(offset: 0));
    setState(() {
      _results = result.items;
      _total = result.total;
    });
  }

  void _loadMore() {
    if (_results.length >= _total) return;
    final result = widget.dict.searchPaged(_currentQuery(offset: _results.length));
    setState(() {
      _results = [..._results, ...result.items];
      _total = result.total;
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _reload();
    });
  }

  void _setLevel(String? level) {
    _debounce?.cancel();
    setState(() => _level = level);
    _reload();
  }

  void _setPos(String? pos) {
    _debounce?.cancel();
    setState(() => _pos = pos);
    _reload();
  }

  void _setTag(String? tag) {
    _debounce?.cancel();
    setState(() => _tag = tag);
    _reload();
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _level = null;
      _pos = null;
      _tag = null;
    });
    _reload();
  }

  bool get _hasActiveFilters =>
      _level != null || _pos != null || _tag != null || _query.isNotEmpty;

  bool get _hasMore => _results.length < _total;

  @override
  Widget build(BuildContext context) {
    final dict = widget.dict;
    final posOptions = _posOptions(dict);
    final tagOptions = _tagOptions(dict);

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
                    '${dict.wordCount} words · ${widget.languageLabel}',
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
                    selected: {widget.isGerman},
                    onSelectionChanged: (selection) =>
                        widget.onLanguageChanged(selection.first),
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
                onChanged: _onSearchChanged,
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
                            _debounce?.cancel();
                            _reload();
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _LevelFilterChip(
                    label: 'All',
                    count: dict.wordCount,
                    selected: _level == null,
                    onTap: () => _setLevel(null),
                  ),
                  for (final level in kCefrLevels) ...[
                    const SizedBox(width: 8),
                    _LevelFilterChip(
                      label: level,
                      count: dict.countForLevel(level),
                      selected: _level == level,
                      onTap: () => _setLevel(level),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterDropdown<String?>(
                      label: 'Part of speech',
                      icon: Icons.tag,
                      value: _pos,
                      options: posOptions,
                      onChanged: (value) =>
                          _setPos(value == _allSentinel ? null : value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilterDropdown<String?>(
                      label: 'Topic',
                      icon: Icons.topic_outlined,
                      value: _tag,
                      options: tagOptions,
                      onChanged: (value) =>
                          _setTag(value == _allSentinel ? null : value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    '$_total result${_total == 1 ? '' : 's'}',                    style: const TextStyle(
                      color: ZovaColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters)
                    TextButton(
                      onPressed: _clearFilters,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: ZovaColors.primary,
                      ),
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child: Text(
                        'No words match your search.',
                        style: TextStyle(color: ZovaColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _results.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index >= _results.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          );
                        }
                        final entry = _results[index];
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

  static const String _allSentinel = '__all__';

  /// All parts of speech as `label: key` dropdown options, sorted by count.
  List<(String, String)> _posOptions(DictionaryService dict) {
    final keys = dict.posKeys.toList()..sort();
    return [
      ('All', _allSentinel),
      for (final key in keys) ('$key (${dict.countForPos(key)})', key),
    ];
  }

  /// Up to 20 most common topic/tag options, sorted by count.
  List<(String, String)> _tagOptions(DictionaryService dict) {
    final ranked = dict.tagKeys.toList()
      ..sort((a, b) {
        final byCount = dict.countForTag(b).compareTo(dict.countForTag(a));
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return [
      ('All', _allSentinel),
      for (final key in ranked.take(20)) ('$key (${dict.countForTag(key)})', key),
    ];
  }
}

/// Standalone drop-down row used for the part-of-speech and topic filters.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final T value;

  /// `(label, key)` pairs; the key is what [onChanged] receives.
  final List<(String, String)> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    var selectedLabel = label;
    for (final (labelText, key) in options) {
      if (key == value) {
        selectedLabel = labelText;
        break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZovaColors.textSecondary.withValues(alpha: 0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.arrow_drop_down),
          hint: Row(
            children: [
              Icon(icon, size: 16, color: ZovaColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                selectedLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ZovaColors.textPrimary,
                ),
              ),
            ],
          ),
          items: [
            for (final (labelText, key) in options)
              DropdownMenuItem<T>(
                value: key as T,
                child: Text(labelText, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
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
      'B2' => ZovaColors.info,
      'C1' => ZovaColors.secondary,
      'C2' => ZovaColors.error,
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
    final code =
        context.watch<LanguageController>().settings.translationLanguage.code;
    final primary = entry.translationIn(code);
    final secondary = code == 'fa' ? entry.englishTranslation : entry.translation;

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
                          entry.gender == null
                              ? entry.partOfSpeech
                              : '${entry.gender} · ${entry.partOfSpeech}',
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
                      primary,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ZovaColors.secondary,
                      ),
                    ),
                    if (secondary.isNotEmpty && secondary != primary) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondary,
                        style: TextStyle(
                          fontSize: 13,
                          color: ZovaColors.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    ],
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
      'B1' => ZovaColors.warning,
      'B2' => ZovaColors.info,
      'C1' => ZovaColors.secondary,
      'C2' => ZovaColors.error,
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
    final controller = context.watch<AppController>();
    final isSaved = controller.progress.savedWords.contains(entry.word);
    final inLeitner = controller.progress.leitnerBoxes.containsKey(entry.word);
    final code =
        context.watch<LanguageController>().settings.translationLanguage.code;
    final meaning = entry.definitionIn(code);

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
              entry.gender == null
                  ? entry.partOfSpeech
                  : '${entry.gender} · ${entry.partOfSpeech}',
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
                entry.translationIn(code),
                textDirection: code == 'fa'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.secondary,
                ),
              ),
            ),
            if (meaning.isNotEmpty && meaning != entry.translationIn(code)) ...[
              const SizedBox(height: 18),
              const Text(
                'Meaning',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ZovaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meaning,
                textDirection:
                    code == 'fa' ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: ZovaColors.textPrimary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      foregroundColor: isSaved
                          ? ZovaColors.success
                          : ZovaColors.textPrimary,
                    ),
                    onPressed: () {
                      if (isSaved) {
                        controller.removeSavedWord(entry.word);
                      } else {
                        controller.saveWord(entry.word);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isSaved
                                ? 'Removed from My Words'
                                : 'Saved to My Words',
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_outline,
                      size: 20,
                    ),
                    label: Text(isSaved ? 'Saved' : 'Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      foregroundColor: ZovaColors.primary,
                    ),
                    onPressed: inLeitner
                        ? null
                        : () {
                            controller.addToLeitner(entry.word);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Added to Leitner Box'),
                              ),
                            );
                          },
                    icon: const Icon(Icons.style_outlined, size: 20),
                    label: Text(inLeitner ? 'In Leitner' : 'Leitner'),
                  ),
                ),
              ],
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
              entry.exampleIn(code),
              textDirection: code == 'fa'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
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
              'This word appears in the A1-B2 course lessons, so you can '
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
