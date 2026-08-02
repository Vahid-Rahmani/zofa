import '../models/grammar_topic.dart';

/// Curated grammar points for the English course, ordered roughly by when
/// learners meet them (A1 -> B1).
abstract final class GrammarContent {
  static const List<GrammarTopic> topics = [
    GrammarTopic(
      id: 'verb_to_be',
      title: 'Verb to be',
      faTitle: 'فعل «بودن»',
      level: 'A1',
      icon: '🧩',
      summary: 'am / is / are — the glue of every sentence.',
      explanation:
          'The verb "to be" connects a subject to a description of it. '
          'I go with am, he/she/it goes with is, and we/you/they go with are.',
      examples: [
        GrammarExample(
          english: 'I am a student.',
          persian: 'من دانش‌آموز هستم.',
        ),
        GrammarExample(
          english: 'She is tall.',
          persian: 'او قد بلند است.',
        ),
        GrammarExample(
          english: 'They are happy.',
          persian: 'آن‌ها خوشحال هستند.',
        ),
      ],
      tip: 'Short forms are very common: I\'m, he\'s, we\'re.',
    ),
    GrammarTopic(
      id: 'articles',
      title: 'a / an / the',
      faTitle: 'حروف تعریف',
      level: 'A1',
      icon: '📦',
      summary: 'One of many, or something already known.',
      explanation:
          'Use a/an for the first time you mention a thing and it is one of '
          'many. Use the when the listener already knows which one you mean.',
      examples: [
        GrammarExample(
          english: 'I saw a cat in the street.',
          persian: 'یک گربه در خیابان دیدم.',
        ),
        GrammarExample(
          english: 'The cat was black.',
          persian: 'آن گربه سیاه بود.',
        ),
      ],
      tip: 'an comes before vowel sounds: an apple, an hour.',
    ),
    GrammarTopic(
      id: 'plurals',
      title: 'Plurals',
      faTitle: 'جمع‌ها',
      level: 'A1',
      icon: '🔢',
      summary: 'More than one of something.',
      explanation:
          'Most nouns add -s. Add -es after s, sh, ch, x and some o words. '
          'Nouns ending in consonant + y change y to ies. A few plurals are '
          'irregular and must be memorised.',
      examples: [
        GrammarExample(
          english: 'one book → two books',
          persian: 'یک کتاب → دو کتاب',
        ),
        GrammarExample(
          english: 'one bus → two buses',
          persian: 'یک اتوبوس → دو اتوبوس',
        ),
        GrammarExample(
          english: 'one baby → two babies',
          persian: 'یک نوزاد → دو نوزاد',
        ),
      ],
      tip: 'Irregulars: child → children, man → men, foot → feet.',
    ),
    GrammarTopic(
      id: 'present_simple',
      title: 'Present Simple',
      faTitle: 'حال ساده',
      level: 'A1',
      icon: '☀️',
      summary: 'Habits, routines and general facts.',
      explanation:
          'Use the present simple for things you do regularly and for facts '
          'that are always true. With he/she/it the verb takes an -s.',
      examples: [
        GrammarExample(
          english: 'I drink tea every morning.',
          persian: 'من هر صبح چای می‌نوشم.',
        ),
        GrammarExample(
          english: 'She works in a bank.',
          persian: 'او در یک بانک کار می‌کند.',
        ),
      ],
      tip: 'Negatives use don\'t / doesn\'t: He doesn\'t like coffee.',
    ),
    GrammarTopic(
      id: 'present_continuous',
      title: 'Present Continuous',
      faTitle: 'حال استمراری',
      level: 'A1',
      icon: '🏃',
      summary: 'Happening right now.',
      explanation:
          'Use am/is/are + verb-ing for actions in progress at this moment.',
      examples: [
        GrammarExample(
          english: 'I am reading a book.',
          persian: 'من دارم کتاب می‌خوانم.',
        ),
        GrammarExample(
          english: 'They are playing football.',
          persian: 'آن‌ها در حال فوتبال بازی کردن هستند.',
        ),
      ],
      tip: 'Signal words: now, at the moment, look!',
    ),
    GrammarTopic(
      id: 'past_simple',
      title: 'Past Simple',
      faTitle: 'گذشته ساده',
      level: 'A1',
      icon: '⏪',
      summary: 'Finished actions in the past.',
      explanation:
          'Use the past simple for actions that started and finished at a '
          'known time. Regular verbs add -ed; common verbs are irregular.',
      examples: [
        GrammarExample(
          english: 'I visited my grandmother yesterday.',
          persian: 'دیروز به دیدن مادربزرگم رفتم.',
        ),
        GrammarExample(
          english: 'She went home early.',
          persian: 'او زود به خانه رفت.',
        ),
      ],
      tip: 'Irregulars to remember: go → went, eat → ate, see → saw.',
    ),
    GrammarTopic(
      id: 'prepositions',
      title: 'Prepositions',
      faTitle: 'حروف اضافه',
      level: 'A2',
      icon: '📍',
      summary: 'in / on / at for time and place.',
      explanation:
          'Use at for exact points (at 7 o\'clock, at the station), on for '
          'days and surfaces (on Monday, on the table), and in for larger '
          'spaces and periods (in August, in the box, in Iran).',
      examples: [
        GrammarExample(
          english: 'The keys are on the table.',
          persian: 'کلیدها روی میز هستند.',
        ),
        GrammarExample(
          english: 'I wake up at 7 o\'clock.',
          persian: 'من ساعت ۷ بیدار می‌شوم.',
        ),
        GrammarExample(
          english: 'We met in July.',
          persian: 'ما در ماه ژوئیه ملاقات کردیم.',
        ),
      ],
    ),
    GrammarTopic(
      id: 'comparatives',
      title: 'Comparatives & Superlatives',
      faTitle: 'تفضیلی و عالی',
      level: 'A2',
      icon: '📈',
      summary: 'Comparing people and things.',
      explanation:
          'Short adjectives take -er / -est (tall → taller → tallest). Long '
          'adjectives use more / most (beautiful → more beautiful). A few '
          'adjectives are irregular.',
      examples: [
        GrammarExample(
          english: 'Amir is taller than me.',
          persian: 'امیر از من قدبلندتر است.',
        ),
        GrammarExample(
          english: 'This is the most beautiful city.',
          persian: 'این زیباترین شهر است.',
        ),
      ],
      tip: 'Irregulars: good → better → best, bad → worse → worst.',
    ),
    GrammarTopic(
      id: 'modals',
      title: 'can / could / should',
      faTitle: 'افعال کمکی',
      level: 'A2',
      icon: '🎯',
      summary: 'Ability, permission, advice.',
      explanation:
          'Modal verbs come before the main verb and never change form. can '
          'shows ability or permission, could is the polite past version, and '
          'should gives advice.',
      examples: [
        GrammarExample(
          english: 'I can swim.',
          persian: 'من می‌توانم شنا کنم.',
        ),
        GrammarExample(
          english: 'You should sleep more.',
          persian: 'تو باید بیشتر بخوابی.',
        ),
      ],
      tip: 'No -s in the third person: He can run fast, not "can runs".',
    ),
    GrammarTopic(
      id: 'future',
      title: 'Future: will & going to',
      faTitle: 'آینده',
      level: 'A2',
      icon: '🔮',
      summary: 'Plans, decisions and predictions.',
      explanation:
          'Use going to for plans you have already made, and will for '
          'spontaneous decisions, promises and predictions.',
      examples: [
        GrammarExample(
          english: 'She is going to travel next week.',
          persian: 'او هفته آینده به سفر خواهد رفت.',
        ),
        GrammarExample(
          english: 'I will help you.',
          persian: 'من به تو کمک خواهم کرد.',
        ),
      ],
      tip: 'Going to = am/is/are + going to + verb.',
    ),
    GrammarTopic(
      id: 'present_perfect',
      title: 'Present Perfect',
      faTitle: 'حال کامل',
      level: 'B1',
      icon: '⏳',
      summary: 'Past experiences linked to now.',
      explanation:
          'Use have/has + past participle for experiences and recent changes '
          'that still matter. There is no exact time given.',
      examples: [
        GrammarExample(
          english: 'I have visited Paris.',
          persian: 'من پاریس را دیده‌ام.',
        ),
        GrammarExample(
          english: 'She has finished her homework.',
          persian: 'او تکالیفش را تمام کرده است.',
        ),
      ],
      tip: 'Watch for ever, never, just, already and yet.',
    ),
    GrammarTopic(
      id: 'first_conditional',
      title: 'First Conditional',
      faTitle: 'جملات شرطی',
      level: 'B1',
      icon: '🚦',
      summary: 'Real possibilities in the future.',
      explanation:
          'Use if + present simple, then will + verb for real future '
          'possibilities. The if-clause never contains will.',
      examples: [
        GrammarExample(
          english: 'If it rains, I will stay home.',
          persian: 'اگر باران ببارد، من خانه می‌مانم.',
        ),
        GrammarExample(
          english: 'If you study, you will pass.',
          persian: 'اگر درس بخوانی، قبول می‌شوی.',
        ),
      ],
      tip: 'The if-clause comes first or second, without a comma when second.',
    ),
  ];
}
