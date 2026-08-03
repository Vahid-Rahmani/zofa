import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/translation_language.dart';
import '../../data/models/translation_result.dart';
import '../../data/services/german_frequency.dart';
import '../../data/services/translation_service.dart';

/// The Dictionary tab: a live, dynamic translation lookup.
///
/// Instead of searching a bundled word list, the learner picks any source and
/// target language pair and the app bridges to a real-time translation
/// provider ([TranslationService]), with definitions, genders and examples
/// fetched on demand. Every lookup is cached locally (LRU + Hive) so repeats
/// are instant and recently viewed words work offline.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  static final TranslationLanguage _english = TranslationLanguage.byCode('en')!;
  static final TranslationLanguage _persian = TranslationLanguage.byCode('fa')!;

  final _searchController = TextEditingController();
  Timer? _debounce;

  late TranslationLanguage _source;
  late TranslationLanguage _target;

  String _query = '';
  TranslationResult? _result;
  TranslationException? _error;
  bool _loading = false;

  /// Autocomplete candidates from the bundled 50k German word list.
  List<String> _suggestions = const [];
  bool _suggestionsLoading = false;

  /// The deterministic "word of the day" from the 50k list.
  String? _wordOfDay;
  bool _wordOfDayLoading = false;

  /// Monotonic token so stale async responses never paint over newer ones.
  int _requestId = 0;

  late final LanguageController _language;

  @override
  void initState() {
    super.initState();
    _language = context.read<LanguageController>();
    _language.addListener(_syncPairToSettings);
    _syncPairToSettings();
  }

  @override
  void dispose() {
    _language.removeListener(_syncPairToSettings);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Re-anchors the From/To pickers to the saved native ↔ learning pair.
  ///
  /// Listens to [LanguageController] so switching the language pair while the
  /// tab stays alive in the `IndexedStack` updates the defaults immediately —
  /// no restart needed. A manual override to an arbitrary pair is preserved
  /// until the pair itself changes.
  void _syncPairToSettings() {
    if (!mounted) return;
    final settings = context.read<LanguageController>().settings;
    final native = TranslationLanguage.byCode(settings.nativeLanguage);
    final learning = TranslationLanguage.byCode(settings.learningLanguage);
    setState(() {
      _source = learning ?? _english;
      _target = native ?? _persian;
      if (_target == _source) _target = _otherOf(_source);
    });
    _refreshGermanContext();
    if (_query.isNotEmpty) _runLookup();
  }

  /// Loads the German 50k context (word of the day + autocomplete source) only
  /// when German is the active source language, so non-German pairs never pay
  /// for the 50k asset.
  void _refreshGermanContext() {
    if (_source.code != 'de') {
      setState(() {
        _suggestions = const [];
        _wordOfDay = null;
      });
      return;
    }
    _loadWordOfDay();
    _refreshSuggestions(_query);
  }

  Future<void> _loadWordOfDay() async {
    if (_wordOfDay != null) return;
    setState(() => _wordOfDayLoading = true);
    final list = await GermanFrequencyList.service;
    if (!mounted) return;
    setState(() {
      _wordOfDay = list.wordOfDay(DateTime.now());
      _wordOfDayLoading = false;
    });
  }

  Future<void> _refreshSuggestions(String query) async {
    if (_source.code != 'de' || query.trim().isEmpty) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    setState(() => _suggestionsLoading = true);
    final list = await GermanFrequencyList.service;
    if (!mounted) return;
    setState(() {
      _suggestions = list.suggestions(query, limit: 6);
      _suggestionsLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _maybeSmartFlip(value);
    _refreshSuggestions(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runLookup);
  }

  /// Whether the current From/To pair is the saved native ↔ learning pair in
  /// either direction. Smart auto-direction only applies to this pair so a
  /// manual override to an arbitrary pair is never overridden.
  bool get _onSavedPair {
    final settings = context.read<LanguageController>().settings;
    final native = TranslationLanguage.byCode(settings.nativeLanguage);
    final learning = TranslationLanguage.byCode(settings.learningLanguage);
    return (_source == learning && _target == native) ||
        (_source == native && _target == learning);
  }

  /// Bidirectional smart lookup: when the saved native ↔ learning pair has
  /// different text directions, typing in the RTL language translates from
  /// native to learning and typing in the LTR language translates from
  /// learning to native. The pickers follow along so the user always sees the
  /// active direction. Pairs with the same direction (and any manual override
  /// to an arbitrary pair) keep the selected direction as-is.
  void _maybeSmartFlip(String query) {
    if (query.isEmpty || !_onSavedPair) return;
    final settings = context.read<LanguageController>().settings;
    final native = TranslationLanguage.byCode(settings.nativeLanguage);
    final learning = TranslationLanguage.byCode(settings.learningLanguage);
    if (native == null || learning == null) return;
    if (native.isRtl == learning.isRtl) return;

    final desiredSource =
        _isRtlText(query) == native.isRtl ? native : learning;
    if (desiredSource != _source) {
      setState(() {
        _source = desiredSource;
        _target = desiredSource == native ? learning : native;
      });
    }
  }

  /// Detects RTL scripts (Persian, Arabic, Hebrew, …) in [text].
  bool _isRtlText(String text) =>
      _rtlScriptPattern.hasMatch(text);

  static final RegExp _rtlScriptPattern =
      RegExp(r'[\u0591-\u08FF\uFB1D-\uFDFD\uFE70-\uFEFC]');

  void _clearSearch() {
    _debounce?.cancel();
    _requestId++;
    _searchController.clear();
    setState(() {
      _query = '';
      _result = null;
      _error = null;
      _loading = false;
      _suggestions = const [];
    });
  }

  /// Fills the search field from an autocomplete or word-of-the-day tap and
  /// runs the live lookup immediately.
  void _pickSuggestion(String word) {
    _debounce?.cancel();
    _requestId++;
    _searchController.text = word;
    _searchController.selection = TextSelection.collapsed(offset: word.length);
    setState(() {
      _query = word;
      _suggestions = const [];
    });
    _runLookup();
  }

  void _changeSource(TranslationLanguage language) {
    setState(() {
      _source = language;
      if (_source == _target) _target = _otherOf(language);
    });
    _refreshGermanContext();
    if (_query.isNotEmpty) _runLookup();
  }

  void _changeTarget(TranslationLanguage language) {
    setState(() {
      _target = language;
      if (_target == _source) _source = _otherOf(language);
    });
    if (_query.isNotEmpty) _runLookup();
  }

  void _swap() {
    setState(() {
      final previous = _source;
      _source = _target;
      _target = previous;
    });
    if (_query.isNotEmpty) _runLookup();
  }

  TranslationLanguage _otherOf(TranslationLanguage language) =>
      language == _english ? _persian : _english;

  Future<void> _runLookup() async {
    final query = _searchController.text.trim();
    final id = ++_requestId;
    if (query.isEmpty) {
      setState(() {
        _result = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await TranslationService.instance.lookup(
        word: query,
        source: _source.code,
        target: _target.code,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on TranslationException catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Live lookups for any language pair — translations, '
                    'genders and examples are fetched on demand.',
                    style: TextStyle(
                      color: ZovaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _LanguagePicker(
                          label: 'From',
                          value: _source,
                          onChanged: _changeSource,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Swap languages',
                        onPressed: _swap,
                        icon: const Icon(Icons.swap_horiz),
                        color: ZovaColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LanguagePicker(
                          label: 'To',
                          value: _target,
                          onChanged: _changeTarget,
                        ),
                      ),
                    ],
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
                onSubmitted: (_) => _runLookup(),
                decoration: InputDecoration(
                  hintText: 'Search a word…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
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
            if (_source.code == 'de' &&
                (_suggestions.isNotEmpty || _suggestionsLoading)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final word in _suggestions)
                      ActionChip(
                        avatar: const Icon(
                          Icons.bolt,
                          size: 16,
                          color: ZovaColors.primary,
                        ),
                        label: Text(word),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ZovaColors.textPrimary,
                        ),
                        backgroundColor: ZovaColors.surface,
                        side: BorderSide(
                          color: ZovaColors.primary.withValues(alpha: 0.25),
                        ),
                        onPressed: () => _pickSuggestion(word),
                      ),
                    if (_suggestionsLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(child: _buildResultArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    if (_query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        children: [
          const _IdleHint(),
          if (_source.code == 'de') ...[
            const SizedBox(height: 16),
            _WordOfDayCard(
              word: _wordOfDay,
              loading: _wordOfDayLoading,
              onTap: _wordOfDay == null
                  ? null
                  : () => _pickSuggestion(_wordOfDay!),
            ),
          ],
        ],
      );
    }
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 14),
            Text(
              'Translating…',
              style: TextStyle(color: ZovaColors.textSecondary),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!.message, onRetry: _runLookup);
    }
    final result = _result;
    if (result == null) {
      return const _IdleHint();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        Row(
          children: [
            Text(
              '${_source.label} → ${_target.label}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(
              label: result.fromCache ? 'Cached' : 'Live',
              live: !result.fromCache,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ResultCard(
          result: result,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EntryDetailScreen(result: result),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final TranslationLanguage value;
  final ValueChanged<TranslationLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ZovaColors.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TranslationLanguage>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.arrow_drop_down),
          hint: Text(label),
          items: [
            for (final language in kTranslationLanguages)
              DropdownMenuItem<TranslationLanguage>(
                value: language,
                child: Text(
                  '${language.label} (${language.code})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (language) {
            if (language != null) onChanged(language);
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.live});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? ZovaColors.success : ZovaColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate, color: ZovaColors.textSecondary, size: 44),
            SizedBox(height: 14),
            Text(
              'Type any word to translate it.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ZovaColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Results are cached on-device, so you can re-open recent '
              'lookups even offline.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ZovaColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordOfDayCard extends StatelessWidget {
  const _WordOfDayCard({
    required this.word,
    required this.loading,
    this.onTap,
  });

  final String? word;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.celebration, color: ZovaColors.primary, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Word of the day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ZovaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (loading)
                      const Text(
                        'Loading…',
                        style: TextStyle(
                          color: ZovaColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else if (word != null)
                      Text(
                        word!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: ZovaColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: ZovaColors.error, size: 44),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ZovaColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: ZovaColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onTap});

  final TranslationResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = result.isRtl;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.word,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                  ),
                  if (result.glossLine != null)
                    Text(
                      result.glossLine!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: ZovaColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: ZovaColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.translation,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.secondary,
                ),
              ),
              if (result.alternates.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final alt in result.alternates)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ZovaColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alt,
                          textDirection:
                              rtl ? TextDirection.rtl : TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ZovaColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (result.example != null) ...[
                const SizedBox(height: 12),
                Text(
                  '“${result.example}”',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: ZovaColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen detail for a dynamic translation result.
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({super.key, required this.result});

  final TranslationResult result;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final scope = context
        .read<LanguageController>()
        .settings
        .learningLanguage;
    final isSaved = controller.progress.savedWordsFor(scope).contains(result.word);
    final inLeitner = controller.progress.leitnerBoxesFor(scope)
        .containsKey(result.word);
    final rtl = result.isRtl;

    return Scaffold(
      appBar: AppBar(
        title: Text(result.word, style: const TextStyle(fontSize: 18)),
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
                        result.word,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                      if (result.glossLine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          result.glossLine!,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: ZovaColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(
                  label: result.fromCache ? 'Cached' : 'Live',
                  live: !result.fromCache,
                ),
              ],
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
                result.translation,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.secondary,
                ),
              ),
            ),
            if (result.definition != null &&
                result.definition!.isNotEmpty) ...[
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
                result.definition!,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: ZovaColors.textPrimary,
                ),
              ),
            ],
            if (result.alternates.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Other translations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ZovaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final alt in result.alternates)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ZovaColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        alt,
                        textDirection:
                            rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 14,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                    ),
                ],
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
                        controller.removeSavedWord(result.word);
                      } else {
                        controller.saveWord(result.word);
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
                            controller.addToLeitner(result.word);
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
            if (result.example != null) ...[
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
                '“${result.example}”',
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: ZovaColors.textPrimary,
                ),
              ),
              if (result.exampleTranslation != null) ...[
                const SizedBox(height: 6),
                Text(
                  result.exampleTranslation!,
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: ZovaColors.textSecondary,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            const Text(
              'Practice it',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Save this word to "My Words" or drop it into a Leitner box to '
              'review it with flashcards until you never forget it.',
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
