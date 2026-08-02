import 'dart:convert';
import 'dart:io';

import 'package:zova/data/models/dictionary_entry.dart';
import 'package:zova/data/services/dictionary_index.dart';
import 'package:zova/data/services/normalize.dart';

/// Symmetric multilingual corpus builder.
///
/// Takes the parallel English and German dictionaries and merges them into the
/// 3-way model (target <-> English <-> Persian): every English headword is
/// linked to its German counterpart through a shared [concept] id, every entry
/// gains an English gloss, English + Persian definitions and example
/// translations, and German nouns keep their grammatical gender.
///
/// Any concept present in only one language is reported by the tool; missing
/// German counterparts live in [kGermanSupplement], missing English glosses in
/// [kEnglishGloss]. Running the tool to zero warnings produces fully symmetric
/// assets.
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

  final enById = <String, Map<String, dynamic>>{};
  final deById = <String, Map<String, dynamic>>{};

  // putIfAbsent keeps the FIRST entry for a key so parallel pairs (e.g. the
  // "hello"/"hi" -> "hallo" family sharing one Persian gloss) always link to
  // their primary counterpart, leaving the sibling concept for a supplement.
  // Supplement entries (ids prefixed `de-`) are never used as partners, so
  // re-running the tool stays idempotent.
  for (final row in rawEn.cast<Map<String, dynamic>>()) {
    enById.putIfAbsent(_keyOf(row), () => row);
  }
  for (final row in rawDe.cast<Map<String, dynamic>>()) {
    if (!_isSupplement(row)) deById.putIfAbsent(_keyOf(row), () => row);
  }

  final enEntries = <DictionaryEntry>[];
  for (final row in rawEn.cast<Map<String, dynamic>>()) {
    final de = deById[_keyOf(row)];
    enEntries.add(_enrich(row, de, isGerman: false));
  }

  final deEntries = <DictionaryEntry>[];
  final missingEnGloss = <String>[];
  for (final row in rawDe.cast<Map<String, dynamic>>()) {
    final id = _entryId(row);
    final en = enById[_keyOf(row)];
    if (en == null) missingEnGloss.add(id);
    deEntries.add(_enrich(row, en, isGerman: true));
  }

  // German counterparts for every English concept still missing one (a German
  // word may already exist for a sibling concept, e.g. "hello" and "hi" both
  // mapping to "hallo" — each concept still needs its own symmetric entry).
  final coveredConcepts = deEntries.map((e) => e.effectiveConcept).toSet();
  final missingDe = <String>[
    for (final e in enEntries)
      if (!coveredConcepts.contains(e.effectiveConcept)) e.effectiveConcept,
  ];
  final extraDe = <DictionaryEntry>[];
  for (final id in missingDe) {
    final supplement = kGermanSupplement[id];
    final enRow = rawEn.cast<Map<String, dynamic>>().firstWhere(
          (r) => _entryId(r) == id,
          orElse: () => const {},
        );
    if (supplement == null || enRow.isEmpty) {
      stdout.writeln('WARN: no German supplement authored for concept "$id"');
      continue;
    }
    extraDe.add(DictionaryEntry(
      word: supplement.$1,
      translation: enRow['translation'] as String,
      englishTranslation: id == 'hi' ? 'hi' : id.replaceAll('-', ' '),
      persianDefinition: _definitionFa(id, enRow['translation'] as String),
      englishDefinition: _definitionEn(id, id.replaceAll('-', ' ')),
      persianExample: supplement.$3,
      englishExample: enRow['example'] as String? ?? '',
      concept: id,
      partOfSpeech: enRow['part_of_speech'] as String,
      level: enRow['level'] as String,
      example: supplement.$2,
      id: 'de-$id',
      lemma: supplement.$1,
      language: 'de',
      gender: supplement.$4,
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
      'missing english glosses for German-only concepts: $missingEnGloss');
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

  // Hard validation: every generated entry must satisfy the 3-way model
  // (word + Persian + English gloss + part of speech + level all present).
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

/// Matches English and German entries by normalised Persian gloss + part of
/// speech, mirroring how the two corpora were authored in parallel.
String _keyOf(Map<String, dynamic> row) {
  final fa = normalizeText(row['translation'] as String? ?? '');
  final pos = row['part_of_speech'] as String? ?? '';
  return '$fa|$pos';
}

String _entryId(Map<String, dynamic> row) => slug(row['word'] as String);

/// Whether [row] is a supplement entry generated by a previous run of this
/// tool (identified by its `de-` id prefix).
bool _isSupplement(Map<String, dynamic> row) =>
    (row['id'] as String? ?? '').startsWith('de-');

DictionaryEntry _enrich(
  Map<String, dynamic> row,
  Map<String, dynamic>? partner, {
  required bool isGerman,
}) {
  final word = row['word'] as String;
  final id = _entryId(row);
  // Prefer already-baked multilingual fields so re-runs are idempotent;
  // fall back to derivation from the partner / curated maps on first run.
  final bakedGlossEn = row['english_translation'] as String?;
  final glossEn = bakedGlossEn ?? (isGerman
      ? (partner?['word'] as String? ?? kEnglishGloss[id] ?? word)
      : word);
  final exampleEn = isGerman
      ? (partner?['example'] as String? ??
          (row['english_example'] as String? ??
              kEnglishExamples[id] ?? ''))
      : (row['example'] as String? ?? '');
  final bakedConcept = row['concept'] as String?;
  final concept = bakedConcept ??
      (isGerman ? (partner != null ? _entryId(partner) : id) : id);
  final bakedPersianExample =
      row['persian_example'] as String? ?? row['example_translation'] as String?;
  final bakedId = row['id'] as String?;
  return DictionaryEntry(
    word: word,
    translation: row['translation'] as String,
    englishTranslation: glossEn,
    persianDefinition: row['persian_definition'] as String? ??
        _definitionFa(id, row['translation'] as String),
    englishDefinition: row['english_definition'] as String? ??
        _definitionEn(id, glossEn),
    persianExample: bakedPersianExample ?? '',
    englishExample: exampleEn,
    concept: concept,
    partOfSpeech: row['part_of_speech'] as String,
    level: row['level'] as String,
    example: row['example'] as String? ?? '',
    id: bakedId ?? (isGerman ? 'de-$id' : id),
    lemma: isGerman ? word : (row['lemma'] as String?),
    language: isGerman ? 'de' : 'en',
    gender: row['gender'] as String?,
    topics: _topics(row),
  );
}

List<String> _topics(Map<String, dynamic> row) =>
    [for (final t in (row['topics'] as List<dynamic>? ?? const [])) t as String];

String _definitionEn(String id, String glossEn) =>
    kDefinitions[id]?.en ?? glossEn;

String _definitionFa(String id, String glossFa) =>
    kDefinitions[id]?.fa ?? glossFa;

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

/// English and Persian definitions for each concept (keyed by the English
/// concept id, i.e. the slug of the English headword). Entries without a
/// curated definition fall back to their gloss.
const Map<String, ({String en, String fa})> kDefinitions = {
  'hello': (en: 'A friendly greeting.', fa: 'سلام، عبارتی دوستانه برای شروع گفتگو.'),
  'hi': (en: 'An informal greeting.', fa: 'سلام، یک احوالپرسی خودمانی.'),
  'goodbye': (en: 'A farewell said when leaving.', fa: 'خداحافظ، هنگام رفتن گفته میشود.'),
  'good-morning': (en: 'A greeting used in the morning.', fa: 'صبح بخیر، سلامی که صبحها گفته میشود.'),
  'good-night': (en: 'A farewell said in the evening before sleeping.', fa: 'شب بخیر، خداحافظی هنگام شب و پیش از خواب.'),
  'please': (en: 'A polite word used when asking.', fa: 'لطفاً، کلمهای مؤدبانه برای درخواست کردن.'),
  'thank-you': (en: 'An expression of gratitude.', fa: 'متشکرم، بیان قدردانی.'),
  'thanks': (en: 'An informal way of saying thank you.', fa: 'ممنون، شکل غیررسمی تشکر.'),
  'sorry': (en: 'An apology or expression of regret.', fa: 'ببخشید، عذرخواهی یا پشیمانی.'),
  'excuse-me': (en: 'A polite phrase to get attention or apologize.', fa: 'ببخشید، عبارتی مؤدبانه برای جلب توجه یا عذرخواهی.'),
  'welcome': (en: 'A greeting to a guest or visitor.', fa: 'خوش آمدید، خوشامدگویی به میهمان.'),
  'yes': (en: 'An affirmative answer.', fa: 'بله، پاسخ مثبت.'),
  'no': (en: 'A negative answer.', fa: 'نه، پاسخ منفی.'),
  'name': (en: 'The word by which a person or thing is known.', fa: 'اسم، کلمهای که شخص یا چیز با آن شناخته میشود.'),
  'friend': (en: 'A person you like and trust.', fa: 'دوست، کسی که او را دوست داریم و به او اعتماد داریم.'),
  'family': (en: 'People related by blood or marriage.', fa: 'خانواده، افراد مرتبط از طریق خون یا ازدواج.'),
  'mother': (en: 'A female parent.', fa: 'مادر، والد زن.'),
  'father': (en: 'A male parent.', fa: 'پدر، والد مرد.'),
  'sister': (en: 'A female sibling.', fa: 'خواهر، خواهرِ شخص.'),
  'brother': (en: 'A male sibling.', fa: 'برادر، برادرِ شخص.'),
  'child': (en: 'A young person.', fa: 'کودک، شخص جوان.'),
  'boy': (en: 'A male child.', fa: 'پسر، کودک مذکر.'),
  'girl': (en: 'A female child.', fa: 'دختر، کودک مؤنث.'),
  'man': (en: 'An adult male human.', fa: 'مرد، انسان بالغ مذکر.'),
  'woman': (en: 'An adult female human.', fa: 'زن، انسان بالغ مؤنث.'),
  'people': (en: 'More than one person.', fa: 'مردم، بیش از یک نفر.'),
  'i': (en: 'The person speaking or writing.', fa: 'من، شخصی که صحبت میکند.'),
  'you': (en: 'The person being spoken to.', fa: 'شما، شخصی که با او صحبت میشود.'),
  'we': (en: 'The speaker and others.', fa: 'ما، گوینده و دیگران.'),
  'one': (en: 'The number 1.', fa: 'یک، عدد یک.'),
  'two': (en: 'The number 2.', fa: 'دو، عدد دو.'),
  'three': (en: 'The number 3.', fa: 'سه، عدد سه.'),
  'four': (en: 'The number 4.', fa: 'چهار، عدد چهار.'),
  'five': (en: 'The number 5.', fa: 'پنج، عدد پنج.'),
  'six': (en: 'The number 6.', fa: 'شش، عدد شش.'),
  'seven': (en: 'The number 7.', fa: 'هفت، عدد هفت.'),
  'eight': (en: 'The number 8.', fa: 'هشت، عدد هشت.'),
  'nine': (en: 'The number 9.', fa: 'نه، عدد نه.'),
  'ten': (en: 'The number 10.', fa: 'ده، عدد ده.'),
  'day': (en: 'A period of 24 hours.', fa: 'روز، یک دورهی بیستوچهار ساعته.'),
  'week': (en: 'A period of seven days.', fa: 'هفته، دورهای هفت روزه.'),
  'today': (en: 'This current day.', fa: 'امروز، روز جاری.'),
  'tomorrow': (en: 'The day after today.', fa: 'فردا، روز بعد از امروز.'),
  'yesterday': (en: 'The day before today.', fa: 'دیروز، روز قبل از امروز.'),
  'sunday': (en: 'The first day of the week.', fa: 'یکشنبه، نخستین روز هفته.'),
  'monday': (en: 'The second day of the week.', fa: 'دوشنبه، دومین روز هفته.'),
  'hour': (en: 'A period of 60 minutes.', fa: 'ساعت، دورهای شصت دقیقهای.'),
  'home': (en: 'The place where you live.', fa: 'خانه، جایی که در آن زندگی میکنید.'),
  'house': (en: 'A building where people live.', fa: 'خانه، ساختمانی که مردم در آن زندگی میکنند.'),
  'room': (en: 'A separate area inside a building.', fa: 'اتاق، فضایی جداگانه داخل ساختمان.'),
  'door': (en: 'A movable panel used to enter or leave.', fa: 'در، صفحهای متحرک برای ورود و خروج.'),
  'window': (en: 'An opening in a wall that lets in light.', fa: 'پنجره، روزنهای در دیوار که نور وارد میکند.'),
  'table': (en: 'Furniture with a flat top for eating or working.', fa: 'میز، وسیلهای با رویهی صاف برای خوردن یا کار کردن.'),
  'chair': (en: 'A seat for one person.', fa: 'صندلی، جای نشستن یک نفر.'),
  'bed': (en: 'Furniture used for sleeping.', fa: 'تخت، وسیلهای برای خوابیدن.'),
  'book': (en: 'A set of printed pages bound together.', fa: 'کتاب، مجموعهای از صفحات چاپی به هم پیوسته.'),
  'pen': (en: 'An instrument for writing with ink.', fa: 'خودکار، ابزاری برای نوشتن با جوهر.'),
  'key': (en: 'An object used to open locks.', fa: 'کلید، وسیلهای برای باز کردن قفل.'),
  'phone': (en: 'A device used to call people.', fa: 'تلفن، دستگاهی برای تماس با دیگران.'),
  'money': (en: 'Coins and notes used to pay.', fa: 'پول، سکه و اسکناس برای پرداخت.'),
  'water': (en: 'A clear liquid we drink and need to live.', fa: 'آب، مایع شفافی که مینوشیم و به آن نیاز داریم.'),
  'food': (en: 'Things you eat.', fa: 'غذا، چیزهایی که میخورید.'),
  'milk': (en: 'A white drink from animals or plants.', fa: 'شیر، نوشیدنی سفیدی از حیوان یا گیاه.'),
  'bread': (en: 'A baked food made from flour.', fa: 'نان، غذای پختهشده از آرد.'),
  'tea': (en: 'A hot drink made from leaves.', fa: 'چای، نوشیدنی داغی که از برگ تهیه میشود.'),
  'coffee': (en: 'A hot drink made from roasted beans.', fa: 'قهوه، نوشیدنی داغی از دانههای بوداده.'),
  'egg': (en: 'An oval food laid by birds.', fa: 'تخممرغ، غذای تخممرغیشکلی که پرندگان میگذارند.'),
  'apple': (en: 'A round fruit that grows on trees.', fa: 'سیب، میوهای گرد که روی درخت رشد میکند.'),
  'red': (en: 'The color of blood and tomatoes.', fa: 'قرمز، رنگ خون و گوجهفرنگی.'),
  'blue': (en: 'The color of the clear sky.', fa: 'آبی، رنگ آسمان صاف.'),
  'green': (en: 'The color of grass and leaves.', fa: 'سبز، رنگ چمن و برگها.'),
  'yellow': (en: 'The color of the sun.', fa: 'زرد، رنگ خورشید.'),
  'black': (en: 'The darkest color.', fa: 'سیاه، تیرهترین رنگ.'),
  'white': (en: 'The lightest color.', fa: 'سفید، روشنترین رنگ.'),
  'big': (en: 'Large in size.', fa: 'بزرگ، در اندازهی بزرگ.'),
  'small': (en: 'Little in size.', fa: 'کوچک، در اندازهی کوچک.'),
  'good': (en: 'Of high quality; pleasant.', fa: 'خوب، باکیفیت و دلپذیر.'),
  'bad': (en: 'Of low quality; unpleasant.', fa: 'بد، بیکیفیت و ناخوشایند.'),
  'new': (en: 'Recently made or discovered.', fa: 'جدید، بهتازگی ساخته یا کشف شده.'),
  'old': (en: 'Having lived or existed for a long time.', fa: 'قدیمی، مدتها پیش ساخته یا سالها زیسته.'),
  'hot': (en: 'Having a high temperature.', fa: 'داغ، دارای دمای بالا.'),
  'cold': (en: 'Having a low temperature.', fa: 'سرد، دارای دمای پایین.'),
  'beautiful': (en: 'Very pleasing to look at.', fa: 'زیبا، بسیار خوشایند برای دیدن.'),
  'eat': (en: 'To put food in your mouth and swallow it.', fa: 'خوردن، قرار دادن غذا در دهان و فرو بردن آن.'),
  'drink': (en: 'To take liquid into your mouth.', fa: 'نوشیدن، بردن مایع به دهان.'),
  'go': (en: 'To move from one place to another.', fa: 'رفتن، حرکت از جایی به جای دیگر.'),
  'come': (en: 'To move toward the speaker.', fa: 'آمدن، حرکت به سمت گوینده.'),
  'see': (en: 'To notice with your eyes.', fa: 'دیدن، با چشم متوجه شدن.'),
  'want': (en: 'To wish for or desire.', fa: 'خواستن، آرزو کردن یا میل داشتن.'),
  'have': (en: 'To own or possess.', fa: 'داشتن، مالک بودن.'),
  'like': (en: 'To enjoy or find pleasant.', fa: 'دوست داشتن، لذت بردن یا خوشایند یافتن.'),
  'work': (en: 'To do a job or task.', fa: 'کار کردن، انجام دادن شغل یا کار.'),
  'live': (en: 'To have your home somewhere.', fa: 'زندگی کردن، خانه داشتن در جایی.'),
  'speak': (en: 'To say words.', fa: 'صحبت کردن، به زبان آوردن کلمات.'),
  'read': (en: 'To look at and understand written words.', fa: 'خواندن، نگاه کردن به کلمات نوشتهشده و فهمیدن آنها.'),
  'write': (en: 'To put words on paper or a screen.', fa: 'نوشتن، قرار دادن کلمات روی کاغذ یا صفحه.'),
  'wake-up': (en: 'To stop sleeping.', fa: 'بیدار شدن، دست کشیدن از خواب.'),
  'morning': (en: 'The early part of the day.', fa: 'صبح، بخش آغازین روز.'),
  'evening': (en: 'The later part of the day.', fa: 'عصر، بخش پایانی روز.'),
  'travel': (en: 'To go from place to place.', fa: 'سفر کردن، رفتن از جایی به جای دیگر.'),
  'trip': (en: 'A journey to another place.', fa: 'سفر، مسافرتی به جایی دیگر.'),
  'airport': (en: 'A place where planes take off and land.', fa: 'فرودگاه، جایی که هواپیماها بلند میشوند و فرود میآیند.'),
  'station': (en: 'A place where trains or buses stop.', fa: 'ایستگاه، جایی که قطار یا اتوبوس توقف میکند.'),
  'train': (en: 'A long vehicle that runs on rails.', fa: 'قطار، وسیلهی طولانی که روی ریل حرکت میکند.'),
  'bus': (en: 'A large road vehicle carrying many people.', fa: 'اتوبوس، وسیلهی نقلیهی بزرگ جادهای برای مسافر.'),
  'ticket': (en: 'A paper that allows you to travel or enter.', fa: 'بلیت، برگهای که اجازهی سفر یا ورود میدهد.'),
  'map': (en: 'A drawing of an area showing places.', fa: 'نقشه، تصویری از یک منطقه که مکانها را نشان میدهد.'),
  'street': (en: 'A road in a town or city.', fa: 'خیابان، راهی در شهر.'),
  'hotel': (en: 'A place where travelers can sleep.', fa: 'هتل، جایی که مسافران میتوانند بخوابند.'),
  'car': (en: 'A four-wheeled road vehicle.', fa: 'ماشین، وسیلهی نقلیهی چهارچرخ.'),
  'taxi': (en: 'A car you pay to ride in.', fa: 'تاکسی، ماشینی که برای سوار شدن پول میدهید.'),
  'weather': (en: 'The condition of the sky and air.', fa: 'هوا، وضعیت آسمان و هوا.'),
  'sun': (en: 'The bright star that gives us light and heat.', fa: 'خورشید، ستارهی درخشان که نور و گرما میدهد.'),
  'rain': (en: 'Water falling from clouds.', fa: 'باران، آبی که از ابرها میبارد.'),
  'snow': (en: 'Frozen water falling as white flakes.', fa: 'برف، آب یخزده که به شکل برفک میبارد.'),
  'wind': (en: 'Moving air.', fa: 'باد، هوای در حال حرکت.'),
  'cloudy': (en: 'Covered with clouds.', fa: 'ابری، پوشیده از ابر.'),
  'sunny': (en: 'Bright with sun.', fa: 'آفتابی، روشن با نور خورشید.'),
  'summer': (en: 'The warmest season of the year.', fa: 'تابستان، گرمترین فصل سال.'),
  'winter': (en: 'The coldest season of the year.', fa: 'زمستان، سردترین فصل سال.'),
  'spring': (en: 'The season when plants begin to grow.', fa: 'بهار، فصلی که گیاهان شروع به رشد میکنند.'),
  'autumn': (en: 'The season when leaves fall.', fa: 'پاییز، فصلی که برگها میریزند.'),
  'season': (en: 'One of the four parts of the year.', fa: 'فصل، یکی از چهار بخش سال.'),
  'health': (en: 'The state of being well.', fa: 'سلامت، حالت تندرست بودن.'),
  'doctor': (en: 'A person trained to treat illness.', fa: 'پزشک، فردی آموزشدیده برای درمان بیماری.'),
  'hospital': (en: 'A place where sick people are treated.', fa: 'بیمارستان، جایی که بیماران درمان میشوند.'),
  'medicine': (en: 'A substance used to treat illness.', fa: 'دارو، مادهای برای درمان بیماری.'),
  'head': (en: 'The top part of the body.', fa: 'سر، بخش بالایی بدن.'),
  'hand': (en: 'The part of the body at the end of the arm.', fa: 'دست، بخش انتهای بازو.'),
  'foot': (en: 'The part of the body you stand on.', fa: 'پا، بخشی از بدن که روی آن میایستید.'),
  'eye': (en: 'The organ used for seeing.', fa: 'چشم، اندامی برای دیدن.'),
  'ear': (en: 'The organ used for hearing.', fa: 'گوش، اندامی برای شنیدن.'),
  'sick': (en: 'Not well; ill.', fa: 'بیمار، ناخوش.'),
  'healthy': (en: 'In good health.', fa: 'سالم، در سلامت کامل.'),
  'pain': (en: 'A feeling of hurt in the body.', fa: 'درد، احساس آسیب در بدن.'),
  'body': (en: 'The whole physical form of a person.', fa: 'بدن، شکل فیزیکی کامل یک شخص.'),
  'dog': (en: 'A common pet animal.', fa: 'سگ، حیوان خانگی رایج.'),
  'cat': (en: 'A small pet animal with fur.', fa: 'گربه، حیوان خانگی کوچک پشمالو.'),
  'bird': (en: 'An animal with wings that lays eggs.', fa: 'پرنده، جانوری با بال که تخم میگذارد.'),
  'horse': (en: 'A large animal people ride.', fa: 'اسب، جانور بزرگ که سوارش میشوند.'),
  'tree': (en: 'A tall plant with a trunk and branches.', fa: 'درخت، گیاه بلند با تنه و شاخه.'),
  'flower': (en: 'The colorful part of a plant.', fa: 'گل، بخش رنگارنگ گیاه.'),
  'river': (en: 'A large stream of water.', fa: 'رودخانه، جریان بزرگ آب.'),
  'mountain': (en: 'A very high hill.', fa: 'کوه، تپهای بسیار بلند.'),
  'forest': (en: 'A large area full of trees.', fa: 'جنگل، منطقهی بزرگ پر از درخت.'),
  'sky': (en: 'The space above the earth.', fa: 'آسمان، فضای بالای زمین.'),
  'bank': (en: 'A place where money is kept.', fa: 'بانک، جایی که پول نگهداری میشود.'),
  'museum': (en: 'A building where objects are shown.', fa: 'موزه، ساختمانی که اشیاء به نمایش گذاشته میشوند.'),
  'park': (en: 'An open area with grass and trees.', fa: 'پارک، فضای باز با چمن و درخت.'),
  'bridge': (en: 'A structure to cross a river or road.', fa: 'پل، سازهای برای عبور از رودخانه یا جاده.'),
  'library': (en: 'A place with many books to read.', fa: 'کتابخانه، جایی با کتابهای زیاد برای خواندن.'),
  'supermarket': (en: 'A large shop selling food and goods.', fa: 'سوپرمارکت، فروشگاه بزرگ مواد غذایی و کالا.'),
  'cinema': (en: 'A place where films are shown.', fa: 'سینما، جایی که فیلم نمایش داده میشود.'),
  'pharmacy': (en: 'A shop that sells medicine.', fa: 'داروخانه، فروشگاهی که دارو میفروشد.'),
  'bakery': (en: 'A shop that sells bread.', fa: 'نانوایی، فروشگاهی که نان میفروشد.'),
  'passport': (en: 'A document needed to travel abroad.', fa: 'گذرنامه، مدرکی برای سفر به خارج.'),
  'luggage': (en: 'Bags you carry when traveling.', fa: 'چمدان، کیفهایی که هنگام سفر همراه دارید.'),
  'beach': (en: 'Sandy ground next to the sea.', fa: 'ساحل، زمین شنی کنار دریا.'),
  'job': (en: 'Work you do to earn money.', fa: 'شغل، کاری که برای کسب درآمد انجام میدهید.'),
  'teacher': (en: 'A person who teaches.', fa: 'معلم، کسی که درس میدهد.'),
  'student': (en: 'A person who studies.', fa: 'دانشآموز، کسی که درس میخواند.'),
  'office': (en: 'A place where people work.', fa: 'اداره، جایی که مردم کار میکنند.'),
  'company': (en: 'A business organization.', fa: 'شرکت، سازمان تجاری.'),
  'boss': (en: 'The person in charge at work.', fa: 'رئیس، شخصی که مسئولیت کار را بر عهده دارد.'),
  'meeting': (en: 'A gathering to discuss things.', fa: 'جلسه، گردهمایی برای گفتگو.'),
  'salary': (en: 'Money paid for work, usually monthly.', fa: 'حقوق، پولی که معمولاً ماهانه برای کار پرداخت میشود.'),
  'colleague': (en: 'A person you work with.', fa: 'همکار، کسی که با او کار میکنید.'),
  'restaurant': (en: 'A place where you buy and eat meals.', fa: 'رستوران، جایی که غذا میخرید و میخورید.'),
  'menu': (en: 'A list of food and drinks.', fa: 'منو، فهرست غذاها و نوشیدنیها.'),
  'waiter': (en: 'A person who serves food in a restaurant.', fa: 'پیشخدمت، کسی که در رستوران غذا سرو میکند.'),
  'breakfast': (en: 'The first meal of the day.', fa: 'صبحانه، نخستین وعدهی غذایی روز.'),
  'lunch': (en: 'A meal eaten in the middle of the day.', fa: 'ناهار، وعدهی غذایی وسط روز.'),
  'dinner': (en: 'The main meal in the evening.', fa: 'شام، وعدهی اصلی در شب.'),
  'soup': (en: 'A hot liquid food.', fa: 'سوپ، غذای مایع داغ.'),
  'salad': (en: 'A cold dish of vegetables.', fa: 'سالاد، غذایی سرد از سبزیجات.'),
  'chicken': (en: 'Meat from a common bird.', fa: 'مرغ، گوشت یک پرندهی رایج.'),
  'fish': (en: 'An animal that lives in water.', fa: 'ماهی، جانوری که در آب زندگی میکند.'),
  'meat': (en: 'The flesh of animals eaten as food.', fa: 'گوشت، گوشت جانوران بهعنوان غذا.'),
  'rice': (en: 'Small white grains cooked as food.', fa: 'برنج، دانههای کوچک سفید که بهعنوان غذا پخته میشوند.'),
  'delicious': (en: 'Very tasty.', fa: 'خوشمزه، بسیار لذیذ.'),
  'hungry': (en: 'Wanting food.', fa: 'گرسنه، میل به غذا داشتن.'),
  'thirsty': (en: 'Wanting to drink.', fa: 'تشنه، میل به نوشیدن داشتن.'),
  'bill': (en: 'A paper showing how much to pay.', fa: 'حساب، برگهای که میزان پرداخت را نشان میدهد.'),
  'happy': (en: 'Feeling pleasure.', fa: 'خوشحال، احساس لذت کردن.'),
  'sad': (en: 'Feeling unhappy.', fa: 'غمگین، احساس ناخشنودی.'),
  'angry': (en: 'Feeling strong displeasure.', fa: 'عصبانی، احساس ناخشنودی شدید.'),
  'tired': (en: 'Needing rest.', fa: 'خسته، نیازمند استراحت.'),
  'afraid': (en: 'Feeling fear.', fa: 'ترسیده، احساس ترس کردن.'),
  'love': (en: 'A strong feeling of affection.', fa: 'عشق، احساس قوی محبت.'),
  'smile': (en: 'A happy expression on the face.', fa: 'لبخند، بیان شادمانه روی صورت.'),
  'cry': (en: 'To shed tears.', fa: 'گریه کردن، اشک ریختن.'),
  'laugh': (en: 'To make sounds of joy.', fa: 'خندیدن، صداهای شادی درآوردن.'),
  'hope': (en: 'A feeling that good things will happen.', fa: 'امید، احساس وقوع اتفاقات خوب.'),
  'bored': (en: 'Feeling uninterested or tired of something.', fa: 'بیحوصله، احساس بیعلاقگی.'),
  'language': (en: 'A system of words used to communicate.', fa: 'زبان، نظام کلمات برای برقراری ارتباط.'),
  'grammar': (en: 'The rules of a language.', fa: 'دستور زبان، قواعد یک زبان.'),
  'education': (en: 'The process of learning.', fa: 'تحصیلات، فرایند یادگیری.'),
  'university': (en: 'A place of higher education.', fa: 'دانشگاه، جایگاه آموزش عالی.'),
  'exam': (en: 'A test of knowledge.', fa: 'امتحان، آزمون دانش.'),
  'learn': (en: 'To gain knowledge or skill.', fa: 'یاد گرفتن، کسب دانش یا مهارت.'),
  'study': (en: 'To spend time learning.', fa: 'مطالعه کردن، صرف وقت برای یادگیری.'),
  'understand': (en: 'To know the meaning of something.', fa: 'فهمیدن، دانستن معنای چیزی.'),
  'explain': (en: 'To make something clear.', fa: 'توضیح دادن، روشن کردن چیزی.'),
  'practice': (en: 'Doing something again to improve.', fa: 'تمرین، انجام دادن چیزی برای پیشرفت.'),
  'improve': (en: 'To make or become better.', fa: 'بهبود دادن، بهتر کردن یا بهتر شدن.'),
  'technology': (en: 'Modern tools and machines.', fa: 'فناوری، ابزارها و ماشینهای مدرن.'),
  'computer': (en: 'An electronic device that processes data.', fa: 'کامپیوتر، دستگاه الکترونیکی پردازش داده.'),
  'internet': (en: 'A global network of computers.', fa: 'اینترنت، شبکهی جهانی کامپیوترها.'),
  'email': (en: 'A message sent electronically.', fa: 'ایمیل، پیامی که به شکل الکترونیکی فرستاده میشود.'),
  'goal': (en: 'Something you want to achieve.', fa: 'هدف، چیزی که میخواهید به آن برسید.'),
  'future': (en: 'The time that is coming.', fa: 'آینده، زمانی که در پیش است.'),
  'change': (en: 'The act of becoming different.', fa: 'تغییر، عمل متفاوت شدن.'),
  'culture': (en: 'The customs and beliefs of a people.', fa: 'فرهنگ، آداب و باورهای یک قوم.'),
  'tradition': (en: 'A custom passed down over time.', fa: 'سنت، رسمی که از دیرباز منتقل شده است.'),
};

/// German counterpart for English concepts that have no German entry yet.
/// `(word, example, exampleFa, gender)`.
const Map<String, (String, String, String, String?)> kGermanSupplement = {
  'thanks': ('Vielen Dank', 'Vielen Dank für deine Hilfe.', 'از کمک تو بسیار متشکرم.', null),
  'thank-you': ('Danke schön', 'Danke schön für deine Hilfe.', 'از کمکت متشکرم.', null),
  'excuse-me': ('Verzeihung', 'Verzeihung, wo ist der Bahnhof?', 'ببخشید، ایستگاه قطار کجاست؟', null),
  'welcome': ('Willkommen', 'Willkommen in unserem Haus!', 'به خانهی ما خوش آمدید!', null),
  'hi': ('hi', 'Hi! Schön dich zu sehen.', 'سلام! از دیدن تو خوشحالم.', null),
  'boy': ('der Junge', 'Der Junge hat ein rotes Fahrrad.', 'پسر یک دوچرخهی قرمز دارد.', 'der'),
  'girl': ('das Mädchen', 'Das Mädchen liest jeden Abend ein Buch.', 'دختر هر شب یک کتاب میخواند.', 'das'),
  'i': ('ich', 'Ich mag Tee.', 'من چای دوست دارم.', null),
  'you': ('Sie', 'Sind Sie bereit?', 'آیا شما آماده هستید؟', null),
  'we': ('wir', 'Wir lernen Englisch.', 'ما انگلیسی یاد میگیریم.', null),
  'six': ('sechs', 'Der Unterricht beginnt um sechs.', 'کلاس ساعت شش شروع میشود.', null),
  'seven': ('sieben', 'Eine Woche hat sieben Tage.', 'در یک هفته هفت روز است.', null),
  'eight': ('acht', 'Das Geschäft öffnet um acht.', 'مغازه ساعت هشت باز میشود.', null),
  'nine': ('neun', 'Sie geht um neun Uhr raus.', 'او ساعت نه بیرون میرود.', null),
  'chair': ('der Stuhl', 'Setz dich auf den Stuhl.', 'روی آن صندلی بنشین.', 'der'),
  'bed': ('das Bett', 'Ich gehe um elf ins Bett.', 'ساعت یازده به رختخواب میروم.', 'das'),
  'pen': ('der Kugelschreiber', 'Kann ich deinen Kugelschreiber borgen?', 'میتوانم خودکارت را قرض بگیرم؟', 'der'),
  'phone': ('das Telefon', 'Mein Telefon liegt auf dem Schreibtisch.', 'تلفنم روی میز است.', 'das'),
  'get-dressed': ('sich anziehen', 'Sie zieht sich schnell an.', 'او سریع لباس میپوشد.', null),
  'brush': ('sich die Zähne putzen', 'Ich putze mir zweimal am Tag die Zähne.', 'من روزی دو بار مسواک میزنم.', null),
  'leave': ('verlassen', 'Wir verlassen um acht das Haus.', 'ما ساعت هشت از خانه خارج میشویم.', null),
  'arrive': ('ankommen', 'Der Zug kommt um neun an.', 'قطار ساعت نه میرسد.', null),
  'morning': ('der Morgen', 'Ich trinke morgens Tee.', 'من صبح چای مینوشم.', 'der'),
  'evening': ('der Abend', 'Wir gehen abends spazieren.', 'ما عصرها قدم میزنیم.', 'der'),
  'hat': ('der Hut', 'Sie hat einen roten Hut.', 'او یک کلاه قرمز دارد.', 'der'),
  'socks': ('die Socken', 'Ich brauche neue Socken.', 'به جوراب جدید نیاز دارم.', 'die'),
  'scarf': ('der Schal', 'Ihr Schal ist aus Wolle.', 'شال گردن او از پشم است.', 'der'),
  'tall': ('hoch', 'Der Turm ist sehr hoch.', 'برج خیلی بلند است.', null),
  'short': ('kurz', 'Sie hat kurze Haare.', 'او موهای کوتاهی دارد.', null),
  'orange': ('orange', 'Sie hat einen orangenen Schal gekauft.', 'او یک شال نارنجی خرید.', null),
  'brown': ('braun', 'Er hat braune Augen.', 'او چشمهای قهوهای دارد.', null),
  'purple': ('lila', 'Die Blumen sind lila.', 'گلها بنفش هستند.', null),
  'close': ('zumachen', 'Mach bitte die Tür zu.', 'لطفاً در را ببند.', null),
  'salt': ('das Salz', 'Gib ein bisschen Salz dazu.', 'کمی نمک اضافه کن.', 'das'),
  'bag': ('die Tasche', 'Ich habe meine Tasche für die Reise gepackt.', 'کیفم را برای سفر بستم.', 'die'),
  'size': ('die Größe', 'Haben Sie dieses Hemd in meiner Größe?', 'این پیراهن را در اندازهی من دارید؟', 'die'),
  'open': ('offen', 'Die Bank ist bis vier Uhr offen.', 'بانک تا ساعت چهار باز است.', null),
  'closed': ('geschlossen', 'Das Museum ist montags geschlossen.', 'موزه دوشنبهها بسته است.', null),
  'station': ('die Haltestelle', 'Wo ist die Haltestelle?', 'ایستگاه کجاست؟', 'die'),
  'season': ('die Jahreszeit', 'Der Herbst ist meine Lieblingsjahreszeit.', 'پاییز فصل مورد علاقهی من است.', 'die'),
  'health': ('die Gesundheit', 'Gesundheit ist wichtiger als Geld.', 'سلامت مهمتر از پول است.', 'die'),
  'ear': ('das Ohr', 'Der Arzt hat meine Ohren untersucht.', 'پزشک گوشهایم را معاینه کرد.', 'das'),
  'pain': ('der Schmerz', 'Ich spüre einen stechenden Schmerz im Rücken.', 'در کمرم درد تیزی حس میکنم.', 'der'),
  'game': ('das Spiel', 'Die Kinder haben ein Spiel gespielt.', 'بچهها یک بازی انجام دادند.', 'das'),
  'picture': ('das Bild', 'Sie zeigte mir Bilder von der Reise.', 'او عکسهای سفر را به من نشان داد.', 'das'),
  'meeting': ('die Besprechung', 'Wir haben mittags eine Besprechung.', 'ظهر یک جلسه داریم.', 'die'),
  'position': ('die Stelle', 'Er bewarb sich um eine neue Stelle.', 'او برای سمتی جدید درخواست داد.', 'die'),
  'manager': ('der Manager', 'Der Manager hat den Plan genehmigt.', 'مدیر برنامه را تأیید کرد.', 'der'),
  'employee': ('der Angestellte', 'Jeder Angestellte bekommt einen Bonus.', 'هر کارمند پاداش میگیرد.', 'der'),
  'lecture': ('der Vortrag', 'Der Vortrag begann um neun.', 'سخنرانی ساعت نه شروع شد.', 'der'),
  'homework': ('die Hausaufgabe', 'Ich habe heute Abend viele Hausaufgaben.', 'امشب تکلیف زیادی دارم.', 'die'),
  'practice': ('die Übung', 'Übung macht den Meister.', 'تمرین باعث کمال میشود.', 'die'),
  'foreign': ('fremd', 'Sie spricht zwei fremde Sprachen.', 'او به دو زبان خارجی صحبت میکند.', null),
  'grammar': ('die Grammatik', 'Grammatik hilft dir, richtig zu schreiben.', 'دستور زبان به درستنویسی کمک میکند.', 'die'),
  'reporter': ('der Reporter', 'Der Reporter stellte viele Fragen.', 'خبرنگار سؤالهای زیادی پرسید.', 'der'),
  'information': ('die Information', 'Wir brauchen mehr Informationen.', 'ما به اطلاعات بیشتری نیاز داریم.', 'die'),
  'website': ('die Website', 'Schau auf unsere Website für Neuigkeiten.', 'برای بهروزرسانیها وبسایت ما را بررسی کنید.', 'die'),
  'internet': ('das Internet', 'Das Internet verbindet Menschen weltweit.', 'اینترنت مردم را در سراسر جهان به هم متصل میکند.', 'das'),
  'social-media': ('die sozialen Medien', 'Soziale Medien sind Teil des Alltags.', 'شبکههای اجتماعی بخشی از زندگی روزمره هستند.', 'die'),
  'fact': ('die Tatsache', 'Das ist eine bekannte Tatsache.', 'آن واقعیتی شناختهشده است.', 'die'),
  'message': ('die Nachricht', 'Ich habe deine Nachricht erhalten.', 'پیام تو را دریافت کردم.', 'die'),
  'story': ('die Geschichte', 'Sie erzählte eine interessante Geschichte.', 'او داستان جالبی تعریف کرد.', 'die'),
  'married': ('verheiratet', 'Sie sind seit zehn Jahren verheiratet.', 'آنها ده سال است که ازدواج کردهاند.', null),
  'party': ('die Party', 'Die Party dauerte bis Mitternacht.', 'مهمانی تا نیمهشب ادامه داشت.', 'die'),
  'visit': ('der Besuch', 'Unser Museumsbesuch war schön.', 'ملاقات ما از موزه دوستداشتنی بود.', 'der'),
  'neighbor': ('der Nachbar', 'Unsere Nachbarn sind sehr freundlich.', 'همسایههای ما خیلی خونگرم هستند.', 'der'),
  'promise': ('das Versprechen', 'Er hat sein Versprechen gehalten.', 'او به قولش وفا کرد.', 'das'),
  'afraid': ('ängstlich', 'Sie hat Angst vor Spinnen.', 'او از عنکبوت میترسد.', null),
  'smile': ('das Lächeln', 'Ihr Lächeln machte mich glücklich.', 'لبخندش من را خوشحال کرد.', 'das'),
  'bored': ('gelangweilt', 'Bei der Besprechung war ich gelangweilt.', 'سر جلسه حوصله سر رفته بودم.', null),
  'disagree': ('nicht zustimmen', 'Wir stimmen beim Preis nicht zu.', 'ما دربارهی قیمت مخالفیم.', null),
  'disadvantage': ('der Nachteil', 'Der einzige Nachteil sind die Kosten.', 'تنها عیب آن هزینهاش است.', 'der'),
  'although': ('obwohl', 'Obwohl es regnete, gingen wir raus.', 'اگرچه باران بارید، بیرون رفتیم.', null),
  'diet': ('die Diät', 'Sie folgt einer ausgewogenen Diät.', 'او رژیم غذایی متعادلی دارد.', 'die'),
  'balanced': ('ausgewogen', 'Ein ausgewogenes Leben ist das Ziel.', 'زندگی متعادل هدف است.', null),
  'mental': ('geistig', 'Sport ist gut für die geistige Gesundheit.', 'ورزش برای سلامت روان مفید است.', null),
  'screen': ('der Bildschirm', 'Der Bildschirm ist zu hell.', 'صفحه نمایش خیلی روشن است.', 'der'),
  'keyboard': ('die Tastatur', 'Ich habe eine neue Tastatur gekauft.', 'صفحهکلید جدیدی خریدم.', 'die'),
  'device': ('das Gerät', 'Dieses Gerät funktioniert ohne Kabel.', 'این دستگاه بدون کابل کار میکند.', 'das'),
  'update': ('das Update', 'Das letzte Update hat den Fehler behoben.', 'آخرین بهروزرسانی مشکل را حل کرد.', 'das'),
  'continue': ('weitermachen', 'Wir machen morgen weiter.', 'فردا ادامه میدهیم.', null),
  'change': ('die Veränderung', 'Veränderung ist nie einfach.', 'تغییر هرگز آسان نیست.', 'die'),
  'retire': ('in Rente gehen', 'Sie will mit sechzig in Rente gehen.', 'او قصد دارد در شصتسالگی بازنشسته شود.', null),
  'savings': ('die Ersparnisse', 'Sie hält ihre Ersparnisse auf der Bank.', 'پساندازش را در بانک نگه میدارد.', 'die'),
  'abroad': ('im Ausland', 'Sie hat zwei Jahre im Ausland studiert.', 'او دو سال خارج از کشور تحصیل کرد.', null),
  'training': ('die Schulung', 'Neue Mitarbeiter bekommen Schulungen.', 'کارمندان جدید آموزش میبینند.', 'die'),
  'vegetarian': ('vegetarisch', 'Sie isst vegetarisch.', 'او گیاهخوار است.', null),
  'house': ('das Haus', 'Ihr Haus ist sehr groß.', 'خانهی آنها خیلی بزرگ است.', 'das'),
  'bakery': ('die Bäckerei', 'Frisches Brot aus der Bäckerei.', 'نان تازه از نانوایی.', 'die'),
};

/// English gloss for German concepts that have no English partner.
const Map<String, String> kEnglishGloss = {
  'guten-abend': 'good evening',
  'danke': 'thank you',
  'handy': 'phone',
  'anziehen': 'get dressed',
  'früh': 'early',
  'spät': 'late',
  'bahnhof': 'station',
  'angst-haben': 'afraid',
  'lächeln': 'smile',
  'vegetarier': 'vegetarian',
};

/// English rendering of the example for German concepts that have no English
/// partner (so every German entry teaches a full 3-way example).
const Map<String, String> kEnglishExamples = {
  'guten-abend': 'Good evening, welcome home.',
  'danke': 'Thank you for your help.',
  'handy': 'My phone is on the desk.',
  'anziehen': 'She gets dressed quickly.',
  'früh': 'I get up early.',
  'spät': 'I am running late today.',
  'bahnhof': 'Where is the station?',
  'angst-haben': 'She is afraid of spiders.',
  'lächeln': 'Her smile made me happy.',
  'vegetarier': 'He is a vegetarian.',
};
