import 'dart:convert';

import 'package:flutter/foundation.dart'
    show SynchronousFuture, compute, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

/// Broad part-of-speech groups used to organise a vocabulary list into
/// learnable sections (e.g. Verbs / Nouns / Adjectives / Adverbs / Other).
enum EnglishSection {
  verb('verb'),
  noun('noun'),
  adjective('adjective'),
  adverb('adverb'),
  other('other');

  const EnglishSection(this.label);

  /// The canonical lowercase label, also used as the section key.
  final String label;
}

/// One irregular English verb: [past] is the simple past and [participle] the
/// past participle. Some forms are written as alternatives (e.g. "was/were").
class IrregularVerb {
  const IrregularVerb({required this.past, required this.participle});

  final String past;
  final String participle;
}

/// The active and passive forms of one English verb across the three tenses
/// the study screens show (present, past, future). [present] is the base
/// (lemma) form.
class VerbForms {
  const VerbForms({
    required this.present,
    required this.past,
    required this.future,
    required this.presentPassive,
    required this.pastPassive,
    required this.futurePassive,
  });

  final String present;
  final String past;
  final String future;
  final String presentPassive;
  final String pastPassive;
  final String futurePassive;

  /// Active-voice forms in Present / Past / Future order.
  List<String> get active => [present, past, future];

  /// Passive-voice forms in Present / Past / Future order.
  List<String> get passive => [presentPassive, pastPassive, futurePassive];
}

/// English grammar data that enriches the bundled 50k frequency word list:
/// part of speech per word, irregular verb forms and templated example
/// sentences.
///
/// The POS map ships as `english_pos.json` and was derived from the Universal
/// Dependencies English corpus (UD_English-EWT, CC BY-SA 4.0); words the
/// corpus never tags resolve to [EnglishSection.other]. Regular verbs are
/// inflected with standard spelling rules; irregular verbs come from the
/// bundled `english_irregular_verbs.json` table.
class EnglishGrammar {
  EnglishGrammar._(this._pos, this._irregular);

  /// Bundled word → part-of-speech label map (`assets/vocabulary/english_pos.json`).
  static const String posAssetPath = 'assets/vocabulary/english_pos.json';

  /// Bundled irregular verb table (`assets/vocabulary/english_irregular_verbs.json`).
  static const String verbsAssetPath =
      'assets/vocabulary/english_irregular_verbs.json';

  final Map<String, String> _pos;
  final Map<String, IrregularVerb> _irregular;

  static Future<EnglishGrammar>? _cache;

  /// Memoised async loader. Parsing runs in a background isolate so the word
  /// map never blocks the UI thread.
  static Future<EnglishGrammar> get service => _cache ??= _load();

  static Future<EnglishGrammar> _load() {
    final posOverride = _assetOverrides[posAssetPath];
    final verbsOverride = _assetOverrides[verbsAssetPath];
    if (posOverride != null || verbsOverride != null) {
      return SynchronousFuture<EnglishGrammar>(
        EnglishGrammar._(
          _parsePos(posOverride ?? '{}'),
          _parseVerbs(verbsOverride ?? '{}'),
        ),
      );
    }
    return _loadFromBundle();
  }

  static Future<EnglishGrammar> _loadFromBundle() async {
    final pos = await rootBundle.loadString(posAssetPath);
    final verbs = await rootBundle.loadString(verbsAssetPath);
    return compute(_parse, _GrammarArgs(pos, verbs));
  }

  /// Test hook mirroring the other bundled services: widget tests serve the
  /// assets synchronously so there is no pending asset I/O under the fake
  /// async test clock. Seed either asset; unseeded assets default to empty.
  static final Map<String, String> _assetOverrides = {};

  @visibleForTesting
  static void seedAsset(String path, String contents) {
    _assetOverrides[path] = contents;
  }

  @visibleForTesting
  static void reset() => _cache = null;

  /// Part-of-speech label for [word] (case-insensitive), e.g. `verb`, `noun`,
  /// `adjective`, `pronoun` — or `null` when the word is not tagged.
  String? partOfSpeech(String word) => _pos[word.toLowerCase().trim()];

  /// The broad [EnglishSection] a word belongs to, for grouping vocab lists.
  EnglishSection sectionOf(String word) {
    final label = partOfSpeech(word);
    return switch (label) {
      'verb' => EnglishSection.verb,
      'noun' => EnglishSection.noun,
      'adjective' => EnglishSection.adjective,
      'adverb' => EnglishSection.adverb,
      _ => EnglishSection.other,
    };
  }

  /// Whether [word] is tagged as a verb.
  bool isVerb(String word) => sectionOf(word) == EnglishSection.verb;

  /// The base (lemma) form of [word]: the word itself when it is already a
  /// base form, otherwise the verb it inflects from ("said" → "say",
  /// "running" → "run", "walks" → "walk").
  String lemma(String word) {
    final w = word.toLowerCase().trim();
    if (w.length < 2) return w;
    if (_irregular.containsKey(w)) return w;
    for (final entry in _irregular.entries) {
      if (_hasForm(entry.value, w)) return entry.key;
    }
    if (w.endsWith('ing')) return _candidate(w.substring(0, w.length - 3));
    if (w.endsWith('ied') && w.length > 3) {
      return '${w.substring(0, w.length - 3)}y';
    }
    if (w.endsWith('ed')) return _candidate(w.substring(0, w.length - 2));
    if (w.endsWith('es') && w.length > 3) {
      return _candidate(w.substring(0, w.length - 2));
    }
    if (w.endsWith('s') && w.length > 2) {
      return _candidate(w.substring(0, w.length - 1));
    }
    return w;
  }

  bool _hasForm(IrregularVerb verb, String w) =>
      verb.past.split('/').contains(w) || verb.participle.split('/').contains(w);

  String _candidate(String base) {
    if (base.length < 2) return base;
    if (base.length >= 2 &&
        base[base.length - 1] == base[base.length - 2] &&
        !_isVowel(base[base.length - 1])) {
      return base.substring(0, base.length - 1);
    }
    return base;
  }

  /// The active/passive conjugation table for [word], or `null` when the word
  /// is not a verb.
  VerbForms? verbForms(String word) {
    if (!isVerb(word)) return null;
    final base = lemma(word);
    final irregular = _irregular[base];
    final past = irregular?.past ?? _regularPast(base);
    final participle = irregular?.participle ?? _regularPast(base);
    return VerbForms(
      present: base,
      past: past,
      future: 'will $base',
      presentPassive: 'am/is/are $participle',
      pastPassive: 'was/were $participle',
      futurePassive: 'will be $participle',
    );
  }

  /// Regular simple-past / past-participle spelling: -d after -e, -ied after
  /// consonant + -y, a doubled final consonant for short CVC verbs, else -ed.
  String _regularPast(String base) {
    if (base.endsWith('e')) return '${base}d';
    if (base.length > 1 &&
        base.endsWith('y') &&
        !_isVowel(base[base.length - 2])) {
      return '${base.substring(0, base.length - 1)}ied';
    }
    if (base.length <= 4 && _matchesCvc(base)) {
      return '$base${base[base.length - 1]}ed';
    }
    return '${base}ed';
  }

  bool _matchesCvc(String w) {
    if (w.length < 3) return false;
    final last = w[w.length - 1];
    final middle = w[w.length - 2];
    final third = w[w.length - 3];
    if (last == 'w' || last == 'x' || last == 'y') return false;
    return !_isVowel(last) && _isVowel(middle) && !_isVowel(third);
  }

  bool _isVowel(String c) => 'aeiou'.contains(c);

  /// Two or three example sentences for [word] that show it in context, picked
  /// by part of speech. Function words return none (their use is idiomatic).
  List<String> exampleSentences(String word, EnglishSection section) {
    switch (section) {
      case EnglishSection.verb:
        final base = lemma(word);
        return [
          'I want to $base.',
          'We will $base tomorrow.',
          'They like to $base every day.',
        ];
      case EnglishSection.noun:
        final w = word.toLowerCase();
        return ['I see the $w.', 'The $w is here.'];
      case EnglishSection.adjective:
        final w = word.toLowerCase();
        return ['It is very $w.', 'This looks $w.', 'She feels $w.'];
      case EnglishSection.adverb:
        final w = word.toLowerCase();
        return ['He runs $w.', 'She speaks $w.', 'They work $w.'];
      case EnglishSection.other:
        return const [];
    }
  }
}

/// Inputs for the background-isolate grammar parse.
class _GrammarArgs {
  const _GrammarArgs(this.posJson, this.verbsJson);

  final String posJson;
  final String verbsJson;
}

/// Top-level callback for [compute].
EnglishGrammar _parse(_GrammarArgs args) => EnglishGrammar._(
      _parsePos(args.posJson),
      _parseVerbs(args.verbsJson),
    );

Map<String, String> _parsePos(String json) {
  final decoded = jsonDecode(json) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, value.toString()));
}

Map<String, IrregularVerb> _parseVerbs(String json) {
  final decoded = jsonDecode(json) as Map<String, dynamic>;
  return decoded.map((key, value) {
    final entry = (value as Map<String, dynamic>);
    return MapEntry(
      key,
      IrregularVerb(
        past: entry['past'] as String,
        participle: entry['participle'] as String,
      ),
    );
  });
}
