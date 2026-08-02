/// Cleans provider text so only plain, readable text reaches the UI.
///
/// Translation providers (Google Translate, Wiktionary, custom endpoints)
/// frequently embed HTML markup and wiki syntax inside their responses —
/// Wiktionary definitions and examples often carry `<a rel="...">`, `<b>`,
/// `<span>`, `{{templates}}` and `[[links]]`. This strips all of that so the
/// reader popup, dictionary results and cached data only ever show clean text.
library;

final RegExp _scriptStyle = RegExp(
  r'<(script|style)[^>]*>.*?</\1>|<(script|style)[^>]*/>',
  dotAll: true,
  caseSensitive: false,
);

final RegExp _htmlTag = RegExp(r'<[^>]*>');

final RegExp _entity = RegExp(
  r'&(?:#(\d+)|#x([0-9a-fA-F]+)|([a-zA-Z][a-zA-Z0-9]+));',
);

final RegExp _wikiTemplate = RegExp(r'\{\{[^{}]*\}\}');

final RegExp _wikiLink = RegExp(r'\[\[[^\]|]*(?:\|([^\]]*))?\]\]');

final RegExp _wikiBareLink = RegExp(
  r'\[(?:https?://|//)[^\]\s]*(?:\s+([^\]]*))?\]',
);

final RegExp _wikiItalicsBold = RegExp(r"'''''|'''|''");

final RegExp _wikiLineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);

final RegExp _leftoverEntity = RegExp(r'&[a-zA-Z#0-9]{1,8};');

final RegExp _whitespaceRun = RegExp(r'\s+');

const Map<String, String> _namedEntities = {
  'amp': '&',
  'quot': '"',
  'apos': "'",
  'lt': '<',
  'gt': '>',
  'nbsp': ' ',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'laquo': '«',
  'raquo': '»',
  'middot': '·',
  'bull': '•',
  'deg': '°',
  'plusmn': '±',
  'times': '×',
  'divide': '÷',
  'euro': '€',
  'pound': '£',
  'yen': '¥',
  'cent': '¢',
  'dagger': '†',
  'minus': '−',
  'shy': '',
  'zwnj': '',
};

/// Strips HTML tags, wiki markup, style/script blocks and HTML entities from
/// [input], collapsing the leftover whitespace into a single trimmed string.
///
/// Idempotent in practice: already-clean text passes through unchanged.
String cleanText(String input) {
  var text = input;
  text = text.replaceAll(_scriptStyle, ' ');
  text = text.replaceAll(_wikiLineBreak, ' ');
  text = text.replaceAll(_htmlTag, ' ');
  text = _decodeEntities(text);
  text = text.replaceAll(_wikiTemplate, ' ');
  text = text.replaceAllMapped(
    _wikiLink,
    (match) {
      final display = match.group(1);
      if (display != null) return display.trim();
      final inner = match.group(0)!;
      return inner.substring(2, inner.length - 2).trim();
    },
  );
  text = text.replaceAllMapped(
    _wikiBareLink,
    (match) {
      final display = match.group(1);
      return display != null && display.trim().isNotEmpty
          ? display.trim()
          : ' ';
    },
  );
  text = text.replaceAll(_wikiItalicsBold, '');
  text = text.replaceAll(_leftoverEntity, ' ');
  text = text.replaceAll(RegExp(r'\(\s*\)'), '');
  text = text.replaceAll(RegExp(r'\[\s*\]'), '');
  text = text.replaceAll(RegExp(r'\{\s*\}'), '');
  text = text.replaceAll(_whitespaceRun, ' ').trim();
  return text;
}

String _decodeEntities(String text) {
  final decoded = StringBuffer();
  var index = 0;
  for (final match in _entity.allMatches(text)) {
    decoded.write(text.substring(index, match.start));
    final decimal = match.group(1);
    final hex = match.group(2);
    final named = match.group(3);
    if (decimal != null) {
      decoded.write(_fromCodePoint(decimal, match.group(0)!));
    } else if (hex != null) {
      decoded.write(_fromCodePoint(hex, match.group(0)!, radix: 16));
    } else {
      decoded.write(_namedEntities[named] ?? match.group(0)!);
    }
    index = match.end;
  }
  decoded.write(text.substring(index));
  return decoded.toString();
}

String _fromCodePoint(String digits, String raw, {int radix = 10}) {
  final code = int.tryParse(digits, radix: radix);
  if (code == null || code < 0) return raw;
  try {
    return String.fromCharCode(code);
  } on RangeError {
    return raw;
  }
}
