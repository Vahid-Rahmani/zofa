import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/book.dart';
import '../../data/services/dictionary.dart';
import '../../data/services/dictionary_service.dart';

/// Interactive reader: paragraphs are rendered as tappable text so the user
/// can look up any word and grow their vocabulary while reading. A toggle
/// switches between the English text and its Persian translation.
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

  /// The loaded dictionary, once available. Drives which words are highlighted
  /// as tappable look-ups in the reader.
  DictionaryService? _dict;

  @override
  void initState() {
    super.initState();
    Dictionary.service.then((dict) {
      if (mounted) setState(() => _dict = dict);
    });
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
    final dict = await Dictionary.service;
    final entry = dict.lookup(word);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZovaColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: Column(
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
                if (entry != null) _LevelPill(level: entry.level),
              ],
            ),
            if (entry?.phonetic != null) ...[
              const SizedBox(height: 2),
              Text(
                entry!.phonetic!,
                style: const TextStyle(
                  fontSize: 13,
                  color: ZovaColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              entry?.translation ?? 'Not in the dictionary yet.',
              textDirection: entry == null ? null : TextDirection.rtl,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: entry == null
                    ? ZovaColors.textSecondary
                    : ZovaColors.primary,
              ),
            ),
            if (entry != null) ...[
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
                      '“${entry.example}”',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.exampleTranslation,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: ZovaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Tap any English word in the story to see its meaning.',
              style: TextStyle(
                fontSize: 12,
                color: ZovaColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              _showPersian ? 'Persian' : 'English',
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
              dict: _dict,
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

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});

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

class _ParagraphPage extends StatelessWidget {
  const _ParagraphPage({
    required this.chapter,
    required this.onWordTap,
    required this.showPersian,
    required this.dict,
  });

  final BookChapter chapter;
  final ValueChanged<String> onWordTap;
  final bool showPersian;
  final DictionaryService? dict;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapter.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ZovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          if (showPersian)
            for (final paragraph in chapter.paragraphs)
              if (paragraph.translation != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    paragraph.translation!,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.8,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    paragraph.text,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                )
          else
            for (final paragraph in chapter.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _TappableParagraph(
                  text: paragraph.text,
                  onWordTap: onWordTap,
                  dict: dict,
                ),
              ),
        ],
      ),
    );
  }
}

class _TappableParagraph extends StatelessWidget {
  const _TappableParagraph({
    required this.text,
    required this.onWordTap,
    required this.dict,
  });

  final String text;
  final ValueChanged<String> onWordTap;
  final DictionaryService? dict;

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
                fontSize: 18,
                height: 1.6,
                color: ZovaColors.textPrimary,
              ),
            );
          }
          final hasTranslation = dict?.lookup(token.word) != null;
          return WidgetSpan(
            child: GestureDetector(
              onTap: () => onWordTap(token.word),
              child: Text(
                token.word,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.6,
                  color:
                      hasTranslation ? ZovaColors.secondary : ZovaColors.textPrimary,
                  fontWeight: hasTranslation ? FontWeight.w700 : FontWeight.w400,
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
              'Chapter $current of $total',
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
