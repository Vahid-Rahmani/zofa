import 'package:flutter/material.dart';

import 'content_text.dart';

/// A flashcard-style vocabulary row: the word, an optional tag badge (gender
/// like `der`/`die`/`das`, or a part of speech), the translation, and an
/// optional CEFR-level badge on the trailing edge.
///
/// Rendered on a dark gradient card so every list of words shares one visual
/// identity. When [liveTranslate] is true the word is rendered through
/// [ContentText] so it is swapped for the live translation into the learner's
/// native language.
class VocabularyCard extends StatelessWidget {
  const VocabularyCard({
    super.key,
    required this.word,
    this.translation,
    this.level,
    this.gender,
    this.onTap,
    this.trailing,
    this.liveTranslate = false,
  });

  final String word;

  /// The gloss shown under the word.
  final String? translation;

  /// CEFR level of the word (e.g. `A1`) or any short tag (e.g. `#6`) rendered
  /// in the amber badge.
  final String? level;

  /// Small badge next to the word (e.g. `der`, `noun`); hidden when null.
  final String? gender;

  final VoidCallback? onTap;

  /// Replaces the amber level badge (e.g. action buttons).
  final Widget? trailing;

  /// Renders [word] through [ContentText] for live translation.
  final bool liveTranslate;

  @override
  Widget build(BuildContext context) {
    final rtl = _isRtl(translation ?? '');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF232526), Color(0xFF414345)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: liveTranslate
                              ? ContentText(
                                  word,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Text(
                                  word,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        if (gender != null && gender!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              gender!,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (translation != null && translation!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        translation!,
                        textDirection:
                            rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (level != null && level!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber, width: 0.8),
                  ),
                  child: Text(
                    level!,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static final RegExp _rtlPattern =
      RegExp(r'[\u0591-\u08FF\uFB1D-\uFDFD\uFE70-\uFEFC]');

  static bool _isRtl(String text) => _rtlPattern.hasMatch(text);
}
