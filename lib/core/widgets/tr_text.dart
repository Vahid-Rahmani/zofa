import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/ui_translation_controller.dart';

/// A [Text] whose content is live-translated into the app's UI language.
///
/// Shows the English source immediately and swaps to the Google-translated
/// text as soon as it arrives; rebuilds on every language change. Degrades
/// gracefully to the English source when no [UiTranslationController] is
/// provided (e.g. in unit/widget tests that pump a screen in isolation).
class TrText extends StatelessWidget {
  const TrText(
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
    final ui = context.watch<UiTranslationController?>();
    return Text(
      ui?.tr(text) ?? text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// Build-context helpers for translating UI strings.
///
/// `context.tr('Courses')` returns the localized string (English while the
/// live translation is pending). The lookup is safe anywhere — including
/// callbacks — because it does not subscribe; to rebuild a screen when
/// translations arrive, watch the controller in `build`
/// (`context.watch<UiTranslationController?>()`) or use [TrText] for visible
/// text.
extension UiTrContext on BuildContext {
  String tr(String text) =>
      Provider.of<UiTranslationController?>(this, listen: false)?.tr(text) ??
      text;

  /// Translates [template] which may contain `{0}`, `{1}`, ... placeholders,
  /// then substitutes the corresponding [args]. The English source must use
  /// the same placeholders.
  String trTempl(String template, List<Object> args) {
    final localized = tr(template);
    var result = localized;
    for (var i = 0; i < args.length; i++) {
      result = result.replaceAll('{$i}', args[i].toString());
    }
    return result;
  }
}
