import 'dart:convert';
import 'dart:io';

// Generates assets/vocabulary/english_pos.json from:
//   1. the bundled 50k English frequency list (assets/dictionary/english_top_50k.json)
//   2. a Universal Dependencies English corpus (CoNLL-U), e.g. UD_English-EWT
//      en_ewt-ud-train.conllu (https://github.com/UniversalDependencies/UD_English-EWT)
//
// For every 50k word, the most frequent universal part-of-speech tag in the
// corpus is chosen and mapped to a learner-friendly label. Words the corpus
// never tags are simply omitted (they group under "other" in the UI).
void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln('usage: dart run tool/build_english_grammar.dart '
        '<english_top_50k.json> <ud.conllu> <out_pos.json>');
    exit(2);
  }
  final words = (jsonDecode(File(args[0]).readAsStringSync(encoding: utf8))
          as List<dynamic>)
      .cast<String>()
      .map((w) => w.toLowerCase())
      .toSet();

  final counts = <String, Map<String, int>>{};
  for (final line in File(args[1]).readAsLinesSync(encoding: utf8)) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final columns = line.split('\t');
    if (columns.length < 5) continue;
    final form = columns[1].trim().toLowerCase();
    final tag = columns[3].trim();
    if (form.isEmpty || tag.isEmpty || tag == '_') continue;
    counts.putIfAbsent(form, () => <String, int>{})[tag] =
        (counts[form]![tag] ?? 0) + 1;
  }

  final pos = <String, String>{};
  for (final word in words) {
    final tags = counts[word];
    if (tags == null || tags.isEmpty) continue;
    String? best;
    var bestCount = 0;
    tags.forEach((tag, count) {
      if (count > bestCount) {
        best = tag;
        bestCount = count;
      }
    });
    final label = _toLabel(best);
    if (label != null) pos[word] = label;
  }

  final out = StringBuffer('{\n');
  final keys = pos.keys.toList()..sort();
  for (var i = 0; i < keys.length; i++) {
    out.write('  "${_escape(keys[i])}": "${pos[keys[i]]}"');
    out.write(i == keys.length - 1 ? '\n' : ',\n');
  }
  out.write('}\n');
  File(args[2]).writeAsStringSync(out.toString(), encoding: utf8);
  stdout.writeln('wrote ${pos.length} tagged words to ${args[2]}');
}

/// Maps a UD universal tag to a learner-friendly part-of-speech label, or null
/// when the tag should be left untagged.
String? _toLabel(String? tag) => switch (tag) {
      'NOUN' => 'noun',
      'VERB' => 'verb',
      'ADJ' => 'adjective',
      'ADV' => 'adverb',
      'PRON' => 'pronoun',
      'PROPN' => 'proper noun',
      'ADP' => 'preposition',
      'DET' => 'determiner',
      'CCONJ' || 'SCONJ' => 'conjunction',
      'AUX' => 'auxiliary',
      'PART' => 'particle',
      'NUM' => 'numeral',
      'INTJ' => 'interjection',
      _ => null,
    };

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n');
