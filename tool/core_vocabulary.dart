import 'dart:convert';
import 'dart:io';

import 'package:zova/data/models/dictionary_entry.dart';
import 'package:zova/data/services/dictionary_index.dart';

/// Symmetric master-dataset builder.
///
/// The bundled dictionaries are **slim and translation-free**: each stores only
/// target-language facts (word, example, part of speech, CEFR level, and — for
/// German nouns — grammatical gender). English and German entries are linked
/// through a shared [concept] id (e.g. `hello` ↔ `hallo`), which is what makes
/// the two dictionaries symmetric: every concept exists in both.
///
/// Any concept present in only one language is reported by the tool; missing
/// German counterparts live in [kGermanSupplement]. Running the tool to zero
/// warnings produces fully symmetric, slim assets.
///
/// Usage:
///   dart run tool/core_vocabulary.dart
///
/// Regenerates `assets/dictionary/english.json`, `german.json` and both
/// `.index.json` sidecars, then prints symmetry and field statistics.
void main(List<String> args) {
  final root = Directory.current.path;
  final enPath = '$root/assets/dictionary/english.json';
  final dePath = '$root/assets/dictionary/german.json';

  final rawEn = jsonDecode(File(enPath).readAsStringSync()) as List<dynamic>;
  final rawDe = jsonDecode(File(dePath).readAsStringSync()) as List<dynamic>;

  final enByConcept = <String, Map<String, dynamic>>{};
  final deByConcept = <String, Map<String, dynamic>>{};
  for (final row in rawEn.cast<Map<String, dynamic>>()) {
    enByConcept.putIfAbsent(_conceptOf(row), () => row);
  }
  for (final row in rawDe.cast<Map<String, dynamic>>()) {
    deByConcept.putIfAbsent(_conceptOf(row), () => row);
  }

  final enEntries = [
    for (final row in rawEn.cast<Map<String, dynamic>>())
      DictionaryEntry.fromJson(row),
  ];

  final deEntries = <DictionaryEntry>[];
  final missingEnPartner = <String>[];
  for (final row in rawDe.cast<Map<String, dynamic>>()) {
    final concept = _conceptOf(row);
    if (!enByConcept.containsKey(concept)) missingEnPartner.add(concept);
    deEntries.add(DictionaryEntry.fromJson(row));
  }

  // German counterparts for every English concept still missing one, so both
  // dictionaries stay symmetric (concept -> the English slug).
  final coveredConcepts = deEntries.map((e) => e.effectiveConcept).toSet();
  final missingDe = <String>[
    for (final e in enEntries)
      if (!coveredConcepts.contains(e.effectiveConcept)) e.effectiveConcept,
  ];
  final extraDe = <DictionaryEntry>[];
  for (final id in missingDe) {
    final supplement = kGermanSupplement[id];
    final enRow = enByConcept[id];
    if (supplement == null || enRow == null) {
      stdout.writeln('WARN: no German supplement authored for concept "$id"');
      continue;
    }
    extraDe.add(DictionaryEntry(
      word: supplement.$1,
      example: supplement.$2,
      concept: id,
      partOfSpeech: enRow['part_of_speech'] as String,
      level: enRow['level'] as String,
      id: 'de-$id',
      lemma: supplement.$1,
      language: 'de',
      gender: supplement.$3,
      topics: _topics(enRow),
    ));
  }

  final allEn = [...enEntries];
  final allDe = [...deEntries, ...extraDe];

  _write('$root/assets/dictionary/english.json', allEn);
  _write('$root/assets/dictionary/german.json', allDe);
  _writeIndex('$root/assets/dictionary/english.index.json', allEn);
  _writeIndex('$root/assets/dictionary/german.index.json', allDe);

  stdout.writeln('');
  stdout.writeln('--- summary ---');
  stdout.writeln('english entries: ${allEn.length}');
  stdout.writeln('german entries:  ${allDe.length}');
  stdout.writeln(
      'symmetric concepts: ${allEn.where((e) => allDe.any((d) => d.concept == e.concept)).length}');
  stdout.writeln(
      'German-only concepts without an English partner: $missingEnPartner');
  final missingDeSupplements =
      missingDe.where((id) => kGermanSupplement[id] == null).toList();
  stdout.writeln(
      'missing German supplements for English concepts: $missingDeSupplements');
  stdout.writeln('----');

  // Symmetry hard check: every concept must exist in both dictionaries.
  final enConcepts = allEn.map((e) => e.effectiveConcept).toSet();
  final deConceptSet = allDe.map((e) => e.effectiveConcept).toSet();
  final asymmetric = enConcepts.difference(deConceptSet).toList()..sort();
  if (asymmetric.isNotEmpty) {
    stderr.writeln(
        'SYMMETRY FAIL: ${asymmetric.length} concepts missing from German: $asymmetric');
    exit(1);
  }
  stdout.writeln('symmetry: OK (${enConcepts.length} shared concepts)');

  // Hard validation: every generated entry must satisfy the slim master-dataset
  // model (word + part of speech + level + example all present).
  final invalid = [
    for (final e in [...allEn, ...allDe])
      if (DictionaryEntry.tryParse(e.toJson()) == null) e.concept,
  ];
  if (invalid.isNotEmpty) {
    stderr.writeln(
        'VALIDATION FAIL: ${invalid.length} entries do not round-trip: $invalid');
    exit(1);
  }
  stdout.writeln('validation: OK (${allEn.length + allDe.length} entries)');

  // Hard check: headwords must be unique within each dictionary so lookups
  // stay unambiguous (and the engine's index remains valid).
  final enDuplicates = _duplicates(allEn);
  final deDuplicates = _duplicates(allDe);
  if (enDuplicates.isNotEmpty || deDuplicates.isNotEmpty) {
    stderr.writeln(
        'DUPLICATE HEADWORDS FAIL: english=$enDuplicates german=$deDuplicates');
    exit(1);
  }
  stdout.writeln('headwords: OK (unique per dictionary)');
}

List<String> _duplicates(List<DictionaryEntry> entries) {
  final seen = <String, int>{};
  for (final e in entries) {
    seen[e.word] = (seen[e.word] ?? 0) + 1;
  }
  return [
    for (final entry in seen.entries)
      if (entry.value > 1) entry.key,
  ]..sort();
}

String _conceptOf(Map<String, dynamic> row) =>
    (row['concept'] as String? ?? row['id'] as String? ?? '').trim();

List<String> _topics(Map<String, dynamic> row) =>
    [for (final t in (row['topics'] as List<dynamic>? ?? const [])) t as String];

void _write(String path, List<DictionaryEntry> entries) {
  File(path).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert([
          for (final e in entries) e.toJson(),
        ])}\n',
  );
  stdout.writeln('wrote: $path (${entries.length} entries)');
}

void _writeIndex(String path, List<DictionaryEntry> entries) {
  final index = DictionaryIndex.build(entries);
  File(path).writeAsStringSync('${index.toJsonString()}\n');
  stdout.writeln('wrote: $path (${index.wordCount} entries, '
      '${index.levelKeys.length} levels)');
}

/// German counterpart (word, example, gender) for English concepts that have no
/// German entry yet. Keyed by the English concept id (slug of the English
/// headword).
const Map<String, (String, String, String?)> kGermanSupplement = {
  'thanks': ('Vielen Dank', 'Vielen Dank für deine Hilfe.', null),
  'thank-you': ('Danke schön', 'Danke schön für deine Hilfe.', null),
  'excuse-me': ('Verzeihung', 'Verzeihung, wo ist der Bahnhof?', null),
  'welcome': ('Willkommen', 'Willkommen in unserem Haus!', null),
  'hi': ('hi', 'Hi! Schön dich zu sehen.', null),
  'boy': ('der Junge', 'Der Junge hat ein rotes Fahrrad.', 'der'),
  'girl': ('das Mädchen', 'Das Mädchen liest jeden Abend ein Buch.', 'das'),
  'i': ('ich', 'Ich mag Tee.', null),
  'you': ('Sie', 'Sind Sie bereit?', null),
  'we': ('wir', 'Wir lernen Englisch.', null),
  'six': ('sechs', 'Der Unterricht beginnt um sechs.', null),
  'seven': ('sieben', 'Eine Woche hat sieben Tage.', null),
  'eight': ('acht', 'Das Geschäft öffnet um acht.', null),
  'nine': ('neun', 'Sie geht um neun Uhr raus.', null),
  'chair': ('der Stuhl', 'Setz dich auf den Stuhl.', 'der'),
  'bed': ('das Bett', 'Ich gehe um elf ins Bett.', 'das'),
  'pen': ('der Kugelschreiber', 'Kann ich deinen Kugelschreiber borgen?', 'der'),
  'phone': ('das Telefon', 'Mein Telefon liegt auf dem Schreibtisch.', 'das'),
  'get-dressed': ('sich anziehen', 'Sie zieht sich schnell an.', null),
  'brush': ('sich die Zähne putzen', 'Ich putze mir zweimal am Tag die Zähne.', null),
  'leave': ('verlassen', 'Wir verlassen um acht das Haus.', null),
  'arrive': ('ankommen', 'Der Zug kommt um neun an.', null),
  'morning': ('der Morgen', 'Ich trinke morgens Tee.', 'der'),
  'evening': ('der Abend', 'Wir gehen abends spazieren.', 'der'),
  'hat': ('der Hut', 'Sie hat einen roten Hut.', 'der'),
  'socks': ('die Socken', 'Ich brauche neue Socken.', 'die'),
  'scarf': ('der Schal', 'Ihr Schal ist aus Wolle.', 'der'),
  'tall': ('hoch', 'Der Turm ist sehr hoch.', null),
  'short': ('kurz', 'Sie hat kurze Haare.', null),
  'orange': ('orange', 'Sie hat einen orangenen Schal gekauft.', null),
  'brown': ('braun', 'Er hat braune Augen.', null),
  'purple': ('lila', 'Die Blumen sind lila.', null),
  'close': ('zumachen', 'Mach bitte die Tür zu.', null),
  'salt': ('das Salz', 'Gib ein bisschen Salz dazu.', 'das'),
  'bag': ('die Tasche', 'Ich habe meine Tasche für die Reise gepackt.', 'die'),
  'size': ('die Größe', 'Haben Sie dieses Hemd in meiner Größe?', 'die'),
  'open': ('offen', 'Die Bank ist bis vier Uhr offen.', null),
  'closed': ('geschlossen', 'Das Museum ist montags geschlossen.', null),
  'station': ('die Haltestelle', 'Wo ist die Haltestelle?', 'die'),
  'season': ('die Jahreszeit', 'Der Herbst ist meine Lieblingsjahreszeit.', 'die'),
  'health': ('die Gesundheit', 'Gesundheit ist wichtiger als Geld.', 'die'),
  'ear': ('das Ohr', 'Der Arzt hat meine Ohren untersucht.', 'das'),
  'pain': ('der Schmerz', 'Ich spüre einen stechenden Schmerz im Rücken.', 'der'),
  'game': ('das Spiel', 'Die Kinder haben ein Spiel gespielt.', 'das'),
  'picture': ('das Bild', 'Sie zeigte mir Bilder von der Reise.', 'das'),
  'meeting': ('die Besprechung', 'Wir haben mittags eine Besprechung.', 'die'),
  'position': ('die Stelle', 'Er bewarb sich um eine neue Stelle.', 'die'),
  'manager': ('der Manager', 'Der Manager hat den Plan genehmigt.', 'der'),
  'employee': ('der Angestellte', 'Jeder Angestellte bekommt einen Bonus.', 'der'),
  'lecture': ('der Vortrag', 'Der Vortrag begann um neun.', 'der'),
  'homework': ('die Hausaufgabe', 'Ich habe heute Abend viele Hausaufgaben.', 'die'),
  'practice': ('die Übung', 'Übung macht den Meister.', 'die'),
  'foreign': ('fremd', 'Sie spricht zwei fremde Sprachen.', null),
  'grammar': ('die Grammatik', 'Grammatik hilft dir, richtig zu schreiben.', 'die'),
  'reporter': ('der Reporter', 'Der Reporter stellte viele Fragen.', 'der'),
  'information': ('die Information', 'Wir brauchen mehr Informationen.', 'die'),
  'website': ('die Website', 'Schau auf unsere Website für Neuigkeiten.', 'die'),
  'internet': ('das Internet', 'Das Internet verbindet Menschen weltweit.', 'das'),
  'social-media': ('die sozialen Medien', 'Soziale Medien sind Teil des Alltags.', 'die'),
  'fact': ('die Tatsache', 'Das ist eine bekannte Tatsache.', 'die'),
  'message': ('die Nachricht', 'Ich habe deine Nachricht erhalten.', 'die'),
  'story': ('die Geschichte', 'Sie erzählte eine interessante Geschichte.', 'die'),
  'married': ('verheiratet', 'Sie sind seit zehn Jahren verheiratet.', null),
  'party': ('die Party', 'Die Party dauerte bis Mitternacht.', 'die'),
  'visit': ('der Besuch', 'Unser Museumsbesuch war schön.', 'der'),
  'neighbor': ('der Nachbar', 'Unsere Nachbarn sind sehr freundlich.', 'der'),
  'promise': ('das Versprechen', 'Er hat sein Versprechen gehalten.', 'das'),
  'afraid': ('ängstlich', 'Sie hat Angst vor Spinnen.', null),
  'smile': ('das Lächeln', 'Ihr Lächeln machte mich glücklich.', 'das'),
  'bored': ('gelangweilt', 'Bei der Besprechung war ich gelangweilt.', null),
  'disagree': ('nicht zustimmen', 'Wir stimmen beim Preis nicht zu.', null),
  'disadvantage': ('der Nachteil', 'Der einzige Nachteil sind die Kosten.', 'der'),
  'although': ('obwohl', 'Obwohl es regnete, gingen wir raus.', null),
  'diet': ('die Diät', 'Sie folgt einer ausgewogenen Diät.', 'die'),
  'balanced': ('ausgewogen', 'Ein ausgewogenes Leben ist das Ziel.', null),
  'mental': ('geistig', 'Sport ist gut für die geistige Gesundheit.', null),
  'screen': ('der Bildschirm', 'Der Bildschirm ist zu hell.', 'der'),
  'keyboard': ('die Tastatur', 'Ich habe eine neue Tastatur gekauft.', 'die'),
  'device': ('das Gerät', 'Dieses Gerät funktioniert ohne Kabel.', 'das'),
  'update': ('das Update', 'Das letzte Update hat den Fehler behoben.', 'das'),
  'continue': ('weitermachen', 'Wir machen morgen weiter.', null),
  'change': ('die Veränderung', 'Veränderung ist nie einfach.', 'die'),
  'retire': ('in Rente gehen', 'Sie will mit sechzig in Rente gehen.', null),
  'savings': ('die Ersparnisse', 'Sie hält ihre Ersparnisse auf der Bank.', 'die'),
  'abroad': ('im Ausland', 'Sie hat zwei Jahre im Ausland studiert.', null),
  'training': ('die Schulung', 'Neue Mitarbeiter bekommen Schulungen.', 'die'),
  'vegetarian': ('vegetarisch', 'Sie isst vegetarisch.', null),
  'house': ('das Haus', 'Ihr Haus ist sehr groß.', 'das'),
  'bakery': ('die Bäckerei', 'Frisches Brot aus der Bäckerei.', 'die'),
};
