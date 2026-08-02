import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/translation_language.dart';
import '../../data/models/translation_result.dart';
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

  /// Monotonic token so stale async responses never paint over newer ones.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    final preferred =
        context.read<LanguageController>().settings.translationLanguage;
    _source = _english;
    _target = TranslationLanguage.byCode(preferred.code) ?? _persian;
    if (_target == _source) _target = _persian;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runLookup);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _requestId++;
    _searchController.clear();
    setState(() {
      _query = '';
      _result = null;
      _error = null;
      _loading = false;
    });
  }

  void _changeSource(TranslationLanguage language) {
    setState(() {
      _source = language;
      if (_source == _target) _target = _otherOf(language);
    });
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
            Expanded(child: _buildResultArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    if (_query.isEmpty) {
      return const _IdleHint();
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
    final isSaved = controller.progress.savedWords.contains(result.word);
    final inLeitner = controller.progress.leitnerBoxes.containsKey(result.word);
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
