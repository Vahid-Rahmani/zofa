import 'dart:convert';
import 'dart:io';

// Generates assets/dictionary/english_top_50k.json from a hermitdave/FrequencyWords
// en_50k.txt dump (word <tab/space> count per line). Keeps the first 50,000
// unique alphabetic tokens (letters, internal apostrophes/hyphens), skipping
// mojibake and non-letter tokens, preserving frequency order.
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: dart run tool/build_english_top_50k.dart <en_50k.txt> <out.json>');
    exit(2);
  }
  final lines = File(args[0]).readAsLinesSync(encoding: utf8);
  final seen = <String>{};
  final words = <String>[];
  for (final line in lines) {
    final w = line.trim().split(RegExp(r'\s+')).first;
    if (!RegExp(r"^[A-Za-z][A-Za-z'-]*$").hasMatch(w)) continue;
    if (w.contains('\uFFFD')) continue;
    final key = w.toLowerCase();
    if (!seen.add(key)) continue;
    words.add(w);
    if (words.length == 50000) break;
  }
  File(args[1]).writeAsStringSync('${jsonEncode(words)}\n');
  stdout.writeln('wrote ${words.length} words to ${args[1]}');
}
