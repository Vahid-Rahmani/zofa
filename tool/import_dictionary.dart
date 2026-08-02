import 'dart:convert';
import 'dart:io';

import 'package:zova/data/models/dictionary_entry.dart';
import 'package:zova/data/services/dictionary_index.dart';
import 'package:zova/data/services/normalize.dart';

const String kUsage = '''
zova dictionary import tool

Imports large open-source dictionary dumps into the bundled JSON assets and
rebuilds the search index sidecars consumed by DictionaryService.

Commands:
  dart run tool/import_dictionary.dart import <dump> --output <entries.json> --index <index.json>
      Import a dump (validated, deduped) into canonical entries JSON and build
      its index sidecar.
  dart run tool/import_dictionary.dart build-index <entries.json> --index <index.json>
      Rebuild only the index sidecar for existing canonical entries JSON.
  dart run tool/import_dictionary.dart strip <entries.json> [--output <entries.json>] [--index <index.json>]
      Rewrite canonical entries JSON dropping any legacy gloss/translation keys
      (the master dataset is slim and translation-free). Rebuilds the index
      sidecar when --index is given.
  dart run tool/import_dictionary.dart stats <entries.json>
      Print level / part-of-speech / tag statistics for canonical entries JSON.

Dump format (JSON array or newline-delimited JSON objects):
  {
    "word": "hello",                  // required
    "example": "Hello!",              // required
    "part_of_speech": "interjection", // required
    "level": "A1",                    // required, A1..C2
    "id": "hello",                    // optional; slugs to the word when absent
    "lemma": "hello",                 // optional base form
    "language": "en",                 // optional ISO 639-1
    "phonetic": "heˈloʊ",             // optional
    "gender": null,                   // optional (German articles)
    "plural": null,                   // optional
    "synonyms": [],                   // optional
    "antonyms": [],                   // optional
    "related_words": [],              // optional
    "irregular_forms": [],            // optional
    "topics": ["greetings"],          // optional
    "tags": ["informal"],             // optional
    "frequency": 1200,                // optional
    "audio_ref": null,                // optional
    "image_ref": null                 // optional
  }
''';

const List<String> kValidLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

void main(List<String> args) {
  if (args.isEmpty) {
    stdout.writeln(kUsage);
    exit(2);
  }
  switch (args[0]) {
    case 'import':
      _runImport(args.sublist(1));
    case 'build-index':
      _runBuildIndex(args.sublist(1));
    case 'strip':
      _runStrip(args.sublist(1));
    case 'stats':
      _runStats(args.sublist(1));
    default:
      stdout.writeln('Unknown command: ${args[0]}\n');
      stdout.writeln(kUsage);
      exit(2);
  }
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

void _runImport(List<String> args) {
  final parsed = _parseArgs(args);
  final dump = parsed.positional.isNotEmpty ? parsed.positional.first : '';
  final output = parsed.flags['output'];
  final index = parsed.flags['index'];
  if (dump.isEmpty || output == null || index == null) {
    stdout.writeln('import requires <dump> --output <entries.json> --index <index.json>');
    exit(2);
  }

  final raw = _readDump(dump);
  final entries = _buildEntries(raw);

  final outputFile = File(output);
  outputFile.createSync(recursive: true);
  outputFile.writeAsStringSync('${jsonEncode([for (final e in entries) e.toJson()])}\n');

  _writeIndex(entries, index);
  _printStats(entries);
}

void _runBuildIndex(List<String> args) {
  final parsed = _parseArgs(args);
  final input = parsed.positional.isNotEmpty ? parsed.positional.first : '';
  final index = parsed.flags['index'];
  if (input.isEmpty || index == null) {
    stdout.writeln('build-index requires <entries.json> --index <index.json>');
    exit(2);
  }

  final entries = _readCanonical(input);
  _writeIndex(entries, index);
  _printStats(entries);
}

/// Rewrites canonical entries JSON through [DictionaryEntry.toJson], which
/// emits only the slim master-dataset fields, dropping legacy gloss keys.
void _runStrip(List<String> args) {
  final parsed = _parseArgs(args);
  final input = parsed.positional.isNotEmpty ? parsed.positional.first : '';
  final output = parsed.flags['output'] ?? input;
  final index = parsed.flags['index'];
  if (input.isEmpty || output.isEmpty) {
    stdout.writeln('strip requires <entries.json> [--output <entries.json>]');
    exit(2);
  }

  final entries = _readCanonical(input);
  final file = File(output);
  file.createSync(recursive: true);
  file.writeAsStringSync('${jsonEncode([for (final e in entries) e.toJson()])}\n');
  stdout.writeln('stripped: $input -> $output (${entries.length} entries)');
  if (index != null) _writeIndex(entries, index);
}

void _runStats(List<String> args) {
  final parsed = _parseArgs(args);
  final input = parsed.positional.isNotEmpty ? parsed.positional.first : '';
  if (input.isEmpty) {
    stdout.writeln('stats requires <entries.json>');
    exit(2);
  }
  _printStats(_readCanonical(input));
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _writeIndex(List<DictionaryEntry> entries, String indexPath) {
  final index = DictionaryIndex.build(entries);
  final file = File(indexPath);
  file.createSync(recursive: true);
  file.writeAsStringSync('${index.toJsonString()}\n');
  stdout.writeln('index written: $indexPath (${index.wordCount} entries, '
      '${index.levelKeys.length} levels)');
}

List<DictionaryEntry> _readCanonical(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
  return [
    for (final item in decoded)
      DictionaryEntry.fromJson(item as Map<String, dynamic>),
  ];
}

List<Map<String, dynamic>> _readDump(String path) {
  final raw = File(path).readAsStringSync();
  final trimmed = raw.trim();
  if (trimmed.startsWith('[')) {
    return [for (final item in jsonDecode(raw) as List<dynamic>) item as Map<String, dynamic>];
  }
  return [
    for (final line in LineSplitter.split(raw))
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
  ];
}

/// Validates [raw] rows, drops invalid ones (with warnings), dedupes by
/// normalised headword and returns canonical [DictionaryEntry]s.
List<DictionaryEntry> _buildEntries(List<Map<String, dynamic>> raw) {
  final seen = <String>{};
  final entries = <DictionaryEntry>[];
  for (var i = 0; i < raw.length; i++) {
    final row = raw[i];
    final word = row['word'] as String? ?? '';
    if (word.trim().isEmpty) {
      _warn('row $i: missing word — skipped');
      continue;
    }
    if (!seen.add(normalizeText(word))) {
      _warn('row $i: duplicate word "$word" — skipped');
      continue;
    }
    final pos = row['part_of_speech'] as String? ?? '';
    if (pos.trim().isEmpty) {
      _warn('row $i: "$word" missing part_of_speech — skipped');
      continue;
    }
    final level = (row['level'] as String? ?? '').trim().toUpperCase();
    if (!kValidLevels.contains(level)) {
      _warn('row $i: "$word" invalid level "${row['level']}" — skipped');
      continue;
    }
    final example = row['example'] as String? ?? '';
    if (example.trim().isEmpty) {
      _warn('row $i: "$word" missing example — skipped');
      continue;
    }
    entries.add(DictionaryEntry(
      word: word,
      partOfSpeech: pos,
      level: level,
      example: example,
      concept: row['concept'] as String?,
      id: row['id'] as String?,
      lemma: row['lemma'] as String?,
      language: row['language'] as String?,
      phonetic: row['phonetic'] as String?,
      gender: row['gender'] as String?,
      plural: row['plural'] as String?,
      synonyms: _listOf(row, 'synonyms'),
      antonyms: _listOf(row, 'antonyms'),
      relatedWords: _listOf(row, 'related_words'),
      irregularForms: _listOf(row, 'irregular_forms'),
      topics: _listOf(row, 'topics'),
      tags: _listOf(row, 'tags'),
      frequency: (row['frequency'] as num?)?.toInt(),
      audioRef: row['audio_ref'] as String?,
      imageRef: row['image_ref'] as String?,
    ));
  }
  return entries;
}

List<String> _listOf(Map<String, dynamic> row, String key) =>
    [for (final t in (row[key] as List<dynamic>? ?? const [])) t as String];

void _printStats(List<DictionaryEntry> entries) {
  final index = DictionaryIndex.build(entries);
  stdout.writeln('entries: ${entries.length}');
  stdout.writeln('levels:');
  for (final level in kValidLevels) {
    final count = index.countForLevel(level);
    if (count > 0) stdout.writeln('  $level: $count');
  }
  if (index.partsOfSpeech.isNotEmpty) {
    stdout.writeln('parts of speech:');
    final sorted = index.partsOfSpeech.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final entry in sorted) {
      stdout.writeln('  ${entry.key}: ${entry.value.length}');
    }
  }
  if (index.tags.isNotEmpty) {
    stdout.writeln('top tags:');
    final sorted = index.tags.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final entry in sorted.take(10)) {
      stdout.writeln('  ${entry.key}: ${entry.value.length}');
    }
  }
}

({List<String> positional, Map<String, String> flags}) _parseArgs(List<String> args) {
  final positional = <String>[];
  final flags = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--')) {
      final eq = arg.indexOf('=');
      if (eq >= 0) {
        flags[arg.substring(2, eq)] = arg.substring(eq + 1);
      } else {
        flags[arg.substring(2)] = args[++i];
      }
    } else {
      positional.add(arg);
    }
  }
  return (positional: positional, flags: flags);
}

void _warn(String message) => stderr.writeln('warning: $message');
