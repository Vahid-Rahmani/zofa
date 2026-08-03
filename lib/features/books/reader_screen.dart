import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/utils/clean_text.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/models/book.dart';
import '../../data/models/translation_result.dart';
import '../../data/services/translation_service.dart';

/// Interactive reader: paragraphs are rendered as tappable text so the user
/// can look up any word (through the live translation bridge) and grow their
/// vocabulary while reading. A toggle switches between the English text and
/// its Persian translation.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _chapterIndex;
  late final PageController _pageController;
  bool _showPersian = false;

  @override
  void initState() {
    super.initState();
    final controller = context.read<AppController>();
    _chapterIndex =
        (controller.progress.bookProgress[widget.book.id] ?? 0)
            .clamp(0, widget.book.chapters.length - 1);
    _pageController = PageController(initialPage: _chapterIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  BookChapter get _chapter => widget.book.chapters[_chapterIndex];

  void _onPageChanged(int index) {
    setState(() => _chapterIndex = index);
    context.read<AppController>().saveBookProgress(widget.book.id, index);
  }

  Future<void> _showWordSheet(String word) async {
    final languageCode =
        context.read<LanguageController>().settings.nativeLanguage;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZovaColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          _WordLookupSheet(word: word, languageCode: languageCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.book.title, style: const TextStyle(fontSize: 18)),
            Text(
              _chapter.title,
              style: const TextStyle(
                fontSize: 13,
                color: ZovaColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showPersian = !_showPersian),
            icon: Icon(
              _showPersian ? Icons.language : Icons.g_translate,
              color: _showPersian ? ZovaColors.secondary : ZovaColors.textSecondary,
              size: 20,
            ),
            label: Text(
              context.tr(_showPersian ? 'Persian' : 'English'),
              style: TextStyle(
                color: _showPersian
                    ? ZovaColors.secondary
                    : ZovaColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.book.chapters.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, chapterIndex) {
            return _ParagraphPage(
              chapter: widget.book.chapters[chapterIndex],
              onWordTap: _showWordSheet,
              showPersian: _showPersian,
            );
          },
        ),
      ),
      bottomNavigationBar: _ChapterBar(
        current: _chapterIndex + 1,
        total: widget.book.chapters.length,
        onPrev: _chapterIndex > 0
            ? () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              )
            : null,
        onNext: _chapterIndex < widget.book.chapters.length - 1
            ? () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              )
            : null,
      ),
    );
  }
}

/// Bottom sheet that looks a word up live through the [TranslationService],
/// showing a loading indicator while the provider answers and an error state
/// with retry when offline.
class _WordLookupSheet extends StatefulWidget {
  const _WordLookupSheet({required this.word, required this.languageCode});

  final String word;
  final String languageCode;

  @override
  State<_WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends State<_WordLookupSheet> {
  static const _noTranslationKey = '__no_translation__';

  TranslationResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await TranslationService.instance.lookupAnySource(
        word: widget.word,
        target: widget.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (result == null) {
          _error = _noTranslationKey;
        } else {
          _result = result;
        }
      });
    } on TranslationException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    final errorText = _error == _noTranslationKey
        ? context.trTempl('No translation found for "{0}".', [widget.word])
        : _error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: SafeArea(
        child: _loading
            ? SizedBox(
                height: 160,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 3),
                      const SizedBox(height: 14),
                      Text(
                        context.trTempl('Looking up "{0}"…', [widget.word]),
                        style:
                            const TextStyle(color: ZovaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : errorText != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.word,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorText,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _lookup,
                        style: FilledButton.styleFrom(
                          backgroundColor: ZovaColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(context.tr('Try again')),
                      ),
                    ],
                  )
                : _resultContent(context),
      ),
    );
  }

  Widget _resultContent(BuildContext context) {
    final result = _result!;
    final rtl = result.isRtl;
    final word = cleanText(result.word);
    final translation = cleanText(result.translation);
    final definition = cleanText(result.definition ?? '');
    final example = cleanText(result.example ?? '');
    final exampleTranslation = cleanText(result.exampleTranslation ?? '');
    final glossLine =
        result.glossLine == null ? null : cleanText(result.glossLine!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                word,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.textPrimary,
                ),
              ),
            ),
            if (glossLine != null)
              Text(
                glossLine,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: ZovaColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          translation,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ZovaColors.primary,
          ),
        ),
        if (definition.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            definition,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: ZovaColors.textSecondary,
            ),
          ),
        ],
        if (example.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ZovaColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“$example”',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                if (exampleTranslation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exampleTranslation,
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: ZovaColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          context.tr('Tap any word in the story to see its meaning.'),
          style: TextStyle(
            fontSize: 12,
            color: ZovaColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _ParagraphPage extends StatelessWidget {
  const _ParagraphPage({
    required this.chapter,
    required this.onWordTap,
    required this.showPersian,
  });

  final BookChapter chapter;
  final ValueChanged<String> onWordTap;
  final bool showPersian;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ZovaColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const TrText(
              'CHAPTER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                color: ZovaColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            chapter.title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: ZovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 56,
            height: 3,
            decoration: BoxDecoration(
              color: ZovaColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 26),
          if (showPersian)
            for (final paragraph in chapter.paragraphs)
              _ParagraphBlock(
                text: paragraph.translation ?? paragraph.text,
                rtl: paragraph.translation != null,
                onWordTap: onWordTap,
              )
          else
            for (final paragraph in chapter.paragraphs)
              _ParagraphBlock(
                text: paragraph.text,
                rtl: false,
                onWordTap: onWordTap,
              ),
        ],
      ),
    );
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({
    required this.text,
    required this.rtl,
    required this.onWordTap,
  });

  final String text;
  final bool rtl;
  final ValueChanged<String> onWordTap;

  @override
  Widget build(BuildContext context) {
    if (rtl) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 18,
            height: 2.0,
            color: ZovaColors.textPrimary,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: _TappableParagraph(text: text, onWordTap: onWordTap),
    );
  }
}

class _TappableParagraph extends StatelessWidget {
  const _TappableParagraph({
    required this.text,
    required this.onWordTap,
  });

  final String text;
  final ValueChanged<String> onWordTap;

  @override
  Widget build(BuildContext context) {
    final words = _splitWords(text);
    return Text.rich(
      TextSpan(
        children: words.map((token) {
          if (!token.isWord) {
            return TextSpan(
              text: token.word,
              style: const TextStyle(
                fontSize: 19,
                height: 1.7,
                color: ZovaColors.textPrimary,
              ),
            );
          }
          return WidgetSpan(
            child: GestureDetector(
              onTap: () => onWordTap(token.word),
              child: Text(
                token.word,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.7,
                  color: ZovaColors.secondary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: ZovaColors.secondary.withValues(alpha: 0.4),
                  decorationThickness: 1.2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static List<_Token> _splitWords(String text) {
    final tokens = <_Token>[];
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (_isLetter(char)) {
        buffer.write(char);
      } else {
        if (buffer.isNotEmpty) {
          tokens.add(_Token(buffer.toString(), isWord: true));
          buffer.clear();
        }
        if (char == ' ') {
          tokens.add(_Token(' ', isWord: false));
        } else {
          tokens.add(_Token(char, isWord: false));
        }
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(_Token(buffer.toString(), isWord: true));
    }
    return tokens;
  }

  static bool _isLetter(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        char == '\u00df' ||
        char == '\u00e9' ||
        char == '\u00fc' ||
        char == '\u00e4' ||
        char == '\u00f6' ||
        char == '\u2019';
  }
}

class _Token {
  _Token(this.word, {required this.isWord});

  final String word;
  final bool isWord;
}

class _ChapterBar extends StatelessWidget {
  const _ChapterBar({
    required this.current,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  final int current;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Container(
      color: ZovaColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              context.trTempl('Chapter {0} of {1}', [current, total]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ZovaColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
