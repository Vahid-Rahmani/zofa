import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/content_translation_controller.dart';

/// A [Text] whose content is live-translated into the native (first) language
/// (the language chosen during onboarding / settings).
///
/// Shows the English source immediately and swaps to the translated text as
/// soon as it arrives; rebuilds on every language change. Degrades gracefully
/// to the English source when no [ContentTranslationController] is provided
/// (e.g. in unit/widget tests that pump a screen in isolation).
class ContentText extends StatelessWidget {
  const ContentText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  /// The English source string (the key used for translation).
  final String text;

  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentTranslationController?>();
    return Text(
      content?.tr(text) ?? text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
