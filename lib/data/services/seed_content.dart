import 'dart:math';

import '../models/book.dart';
import '../models/course.dart';
import '../models/dictionary_entry.dart';
import '../models/exercise.dart';
import 'dictionary.dart';
import 'dictionary_service.dart';

/// Bundled educational content for zova.
///
/// Everything here is written from scratch in the B-Amooz style: courses and
/// lessons are generated from the bundled [DictionaryData] so vocabulary,
/// translations, examples and proficiency levels (A1/A2/B1) stay in one place,
/// and every book ships with a Persian translation for bilingual reading.
///
/// All models are JSON-serialisable, so this content can later move to the
/// backend and be fetched per course without touching the UI.
abstract final class SeedContent {
  static final List<Book> books = [
    _littleLight,
    _walkInThePark,
    _catAndMouse,
    _lostKite,
    _sundayMarket,
    _gardenOfTheOldHouse,
    _letterFromLisbon,
    _placeToStart,
    _lostWallet,
    _nightInTheCity,
  ];

  // ---------------------------------------------------------------------------
  // Course
  // ---------------------------------------------------------------------------

  /// Builds the English roadmap course. Lessons and their exercises are
  /// generated from the bundled [Dictionary.service], so the JSON dictionary
  /// stays the single source of truth for vocabulary. Memoised so the Home
  /// dashboard and the Courses tab share one loaded course.
  static Future<Course>? _englishCourseCache;

  static Future<Course> englishCourse() =>
      _englishCourseCache ??= _loadEnglishCourse();

  static Future<Course> _loadEnglishCourse() async {
    final dict = await Dictionary.service;
    return _essentialEnglish(dict);
  }

  static Course _essentialEnglish(DictionaryService dict) {
    return Course(
      id: 'course_english_essential',
      title: 'Essential English',
    description:
        'A complete roadmap for Persian speakers: foundations (A1), everyday '
        'English (A2) and confident English (B1), with hundreds of words, real '
        'examples and interactive exercises.',
    color: 0xFF3D7BFF,
    language: 'English',
    nativeLanguage: 'Persian',
    icon: '🇬🇧',
    levels: [
      CourseLevel(
        id: 'level_a1_foundations',
        title: 'Foundations',
        level: 'A1',
        icon: '🌱',
        description: 'Greetings, numbers, family and the most useful words.',
        lessons: [
          _lesson(
            dict: dict,
            id: 'lesson_a1_greetings',
            title: 'Greetings',
            icon: '👋',
            level: 'A1',
            topics: ['greetings'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_introductions',
            title: 'Introductions',
            icon: '🤝',
            level: 'A1',
            topics: ['introductions', 'polite'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_numbers_days',
            title: 'Numbers & Days',
            icon: '🔢',
            level: 'A1',
            topics: ['numbers', 'days', 'time'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_family_people',
            title: 'Family & People',
            icon: '👨‍👩‍👧',
            level: 'A1',
            topics: ['family', 'people'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_home_objects',
            title: 'Home & Objects',
            icon: '🏠',
            level: 'A1',
            topics: ['home', 'objects'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_food_drink',
            title: 'Food & Drink',
            icon: '🍎',
            level: 'A1',
            topics: ['food', 'drinks'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_colors_descriptions',
            title: 'Colors & Descriptions',
            icon: '🎨',
            level: 'A1',
            topics: ['colors', 'descriptions'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_everyday_verbs',
            title: 'Everyday Verbs',
            icon: '🏃',
            level: 'A1',
            topics: ['verbs'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_daily_routine',
            title: 'Daily Routine',
            icon: '⏰',
            level: 'A1',
            topics: ['routine', 'time'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a1_clothes',
            title: 'Clothes',
            icon: '👗',
            level: 'A1',
            topics: ['clothes'],
          ),
        ],
      ),
      CourseLevel(
        id: 'level_a2_everyday',
        title: 'Everyday English',
        level: 'A2',
        icon: '🚶',
        description:
            'Shopping, travel, health, work and the language of daily life.',
        lessons: [
          _lesson(
            dict: dict,
            id: 'lesson_a2_shopping_money',
            title: 'Shopping & Money',
            icon: '🛍️',
            level: 'A2',
            topics: ['shopping', 'money'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_travel_directions',
            title: 'Travel & Directions',
            icon: '✈️',
            level: 'A2',
            topics: ['travel', 'directions'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_weather_seasons',
            title: 'Weather & Seasons',
            icon: '🌦️',
            level: 'A2',
            topics: ['weather', 'seasons'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_health_body',
            title: 'Health & Body',
            icon: '❤️',
            level: 'A2',
            topics: ['health', 'body'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_hobbies_freetime',
            title: 'Hobbies & Free Time',
            icon: '🎨',
            level: 'A2',
            topics: ['hobbies'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_work_jobs',
            title: 'Work & Jobs',
            icon: '💼',
            level: 'A2',
            topics: ['jobs'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_restaurant',
            title: 'At the Restaurant',
            icon: '🍽️',
            level: 'A2',
            topics: ['restaurant'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_emotions',
            title: 'Emotions & Feelings',
            icon: '😊',
            level: 'A2',
            topics: ['emotions'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_animals_nature',
            title: 'Animals & Nature',
            icon: '🐾',
            level: 'A2',
            topics: ['animals', 'nature'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_a2_around_town',
            title: 'Around Town',
            icon: '🏙️',
            level: 'A2',
            topics: ['places'],
          ),
        ],
      ),
      CourseLevel(
        id: 'level_b1_confident',
        title: 'Confident English',
        level: 'B1',
        icon: '🚀',
        description:
            'Career, studies, opinions and the skills for real conversations.',
        lessons: [
          _lesson(
            dict: dict,
            id: 'lesson_b1_career',
            title: 'Career & Workplace',
            icon: '📈',
            level: 'B1',
            topics: ['career'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_education',
            title: 'Education & Study',
            icon: '🎓',
            level: 'B1',
            topics: ['education'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_media_news',
            title: 'Media & News',
            icon: '📰',
            level: 'B1',
            topics: ['media'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_relationships',
            title: 'Relationships & Social Life',
            icon: '💞',
            level: 'B1',
            topics: ['relationships'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_opinions',
            title: 'Opinions & Debates',
            icon: '💭',
            level: 'B1',
            topics: ['opinions'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_lifestyle',
            title: 'Health & Lifestyle',
            icon: '🌿',
            level: 'B1',
            topics: ['lifestyle'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_technology',
            title: 'Technology & Internet',
            icon: '💻',
            level: 'B1',
            topics: ['technology'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_goals',
            title: 'Future Plans & Goals',
            icon: '🎯',
            level: 'B1',
            topics: ['goals'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_money_finance',
            title: 'Money & Finance',
            icon: '💳',
            level: 'B1',
            topics: ['finance', 'money'],
          ),
          _lesson(
            dict: dict,
            id: 'lesson_b1_travel_culture',
            title: 'Travel & Culture',
            icon: '🌍',
            level: 'B1',
            topics: ['culture', 'travel'],
          ),
        ],
      ),
    ],
  );
  }

  /// Builds one lesson from the dictionary entries that match [level] and any
  /// of [topics], then generates a full set of interactive exercises.
  static Lesson _lesson({
    required DictionaryService dict,
    required String id,
    required String title,
    required String icon,
    required String level,
    required List<String> topics,
  }) {
    final words = dict.entries
        .where((e) => e.level == level && topics.any(e.topics.contains))
        .toList();
    return Lesson(
      id: id,
      title: title,
      icon: icon,
      exercises: _exercises(words, dict, level, id),
    );
  }

  static List<Exercise> _exercises(
    List<DictionaryEntry> words,
    DictionaryService dict,
    String level,
    String lessonId,
  ) {
    const target = 8;
    final words1 = List<DictionaryEntry>.from(words);
    if (words1.length < target) {
      final extras = dict.entries
          .where((e) => e.level == level && !words1.contains(e))
          .take(target - words1.length);
      words1.addAll(extras);
    }
    final selected = words1.take(target).toList();

    final exercises = <Exercise>[
      Exercise(
        type: ExerciseType.flashcard,
        prompt: 'Learn these words',
        words: [for (final w in selected) w.word],
        pairs: {for (final w in selected) w.word: w.translation},
        examples: {for (final w in selected) w.word: w.example},
      ),
    ];

    for (final w in selected.take(4)) {
      exercises.add(
        Exercise(
          type: ExerciseType.chooseAnswer,
          prompt: 'What does "${w.word}" mean?',
          options: _distractors(
            correct: w.translation,
            pool: _translationsOf(dict, level),
            seed: w.word.length + selected.indexOf(w) * 7 + lessonId.length,
          ),
          correctAnswer: w.translation,
        ),
      );
    }

    exercises.add(
      Exercise(
        type: ExerciseType.pairs,
        prompt: 'Match the pairs',
        pairs: {for (final w in selected.take(4)) w.word: w.translation},
      ),
    );

    for (final w in selected.skip(4).take(2)) {
      exercises.add(
        Exercise(
          type: ExerciseType.translate,
          prompt: 'Translate "${w.word}"',
          correctAnswer: w.translation,
        ),
      );
    }

    for (final w in selected.skip(6).take(2)) {
      exercises.add(
        Exercise(
          type: ExerciseType.chooseAnswer,
          prompt: '«${w.translation}» یعنی چه؟',
          options: _distractors(
            correct: w.word,
            pool: _wordsOf(dict, level),
            seed: w.translation.length * 3 + lessonId.length + 11,
          ),
          correctAnswer: w.word,
        ),
      );
    }

    return exercises;
  }

  static List<String> _translationsOf(DictionaryService dict, String level) =>
      dict.entries.where((e) => e.level == level).map((e) => e.translation).toList();

  static List<String> _wordsOf(DictionaryService dict, String level) =>
      dict.entries.where((e) => e.level == level).map((e) => e.word).toList();

  /// Returns [correct] plus up to three unique distractors, shuffled with a
  /// deterministic seed so lesson content stays stable between runs.
  static List<String> _distractors({
    required String correct,
    required List<String> pool,
    required int seed,
  }) {
    final candidates = pool.where((p) => p != correct).toSet().toList()..shuffle(Random(seed));
    final options = <String>[correct];
    for (final c in candidates) {
      if (options.length >= 4) break;
      options.add(c);
    }
    options.shuffle(Random(seed + 1));
    return options;
  }

  // ---------------------------------------------------------------------------
  // Books
  // ---------------------------------------------------------------------------

  static const Book _littleLight = Book(
    id: 'book_little_light',
    title: 'The Little Light',
    author: 'zova Studio',
    description:
        'A gentle story about a small lamp that learns to shine for others.',
    cover: '🕯️',
    difficulty: 'Beginner',
    level: 'A1',
    chapters: [
      BookChapter(
        id: 'ch_light_1',
        title: 'The dark room',
        paragraphs: [
          BookParagraph(
            text: 'In a small house there was a small room. The room was very dark. In the corner stood a little lamp.',
            translation: 'در خانهی کوچکی اتاق کوچکی بود. اتاق خیلی تاریک بود. در گوشه یک چراغ کوچک ایستاده بود.',
          ),
          BookParagraph(
            text: 'The little lamp wanted to shine. But every time it tried, it was afraid.',
            translation: 'چراغ کوچک میخواست بدرخشد. اما هر بار که تلاش میکرد، میترسید.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_light_2',
        title: 'One little step',
        paragraphs: [
          BookParagraph(
            text: 'One day a bird came to the window. "Shine," said the bird. "The night is cold without light."',
            translation: 'یک روز پرندهای به پنجره آمد. پرنده گفت: «بدرخش. شب بدون نور سرد است.»',
          ),
          BookParagraph(
            text: 'The little lamp took a deep breath. Then it turned on its light.',
            translation: 'چراغ کوچک نفس عمیقی کشید. بعد چراغش را روشن کرد.',
          ),
          BookParagraph(
            text: 'The room was warm and bright. The bird sang a happy song.',
            translation: 'اتاق گرم و روشن شد. پرنده آواز شادی خواند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_light_3',
        title: 'Every night',
        paragraphs: [
          BookParagraph(
            text: 'From that day on, the little lamp shone every night. It was no longer afraid.',
            translation: 'از آن روز به بعد، چراغ کوچک هر شب میدرخشید. دیگر نمیترسید.',
          ),
          BookParagraph(
            text: 'The house was never dark again. And the lamp always remembered: light is best when it is shared.',
            translation: 'خانه دیگر هرگز تاریک نشد. و چراغ همیشه به یاد داشت: نور وقتی بهتر است که تقسیم شود.',
          ),
        ],
      ),
    ],
  );

  static const Book _walkInThePark = Book(
    id: 'book_walk_park',
    title: 'A Walk in the Park',
    author: 'zova Studio',
    description:
        'Two friends spend a sunny afternoon discovering the simple joys of a park.',
    cover: '🌳',
    difficulty: 'Beginner',
    level: 'A1',
    chapters: [
      BookChapter(
        id: 'ch_park_1',
        title: 'A sunny day',
        paragraphs: [
          BookParagraph(
            text: 'Anna and Ben met at the park gate. The sky was blue and the sun was warm.',
            translation: 'آنا و بن دم دروازهی پارک همدیگر را دیدند. آسمان آبی بود و خورشید گرم.',
          ),
          BookParagraph(
            text: '"Let us walk by the lake," said Anna. Ben nodded and smiled.',
            translation: 'آنا گفت: «بیا کنار دریاچه قدم بزنیم.» بن سر تکان داد و لبخند زد.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_park_2',
        title: 'The little duck',
        paragraphs: [
          BookParagraph(
            text: 'By the lake they saw a little duck with three baby ducks. The baby ducks swam in a line.',
            translation: 'کنار دریاچه اردکی کوچک با سه جوجهاردک دیدند. جوجهاردکها پشت سر هم شنا میکردند.',
          ),
          BookParagraph(
            text: 'Anna took a piece of bread from her bag and gave it to the ducks.',
            translation: 'آنا یک تکه نان از کیفهاش درآورد و به اردکها داد.',
          ),
          BookParagraph(
            text: '"That was kind," said Ben. "Let us come back tomorrow." And they did.',
            translation: 'بن گفت: «خیلی مهربان بودی. بیا فردا دوباره بیاییم.» و آنها دوباره آمدند.',
          ),
        ],
      ),
    ],
  );

  static const Book _catAndMouse = Book(
    id: 'book_cat_mouse',
    title: 'The Cat and the Mouse',
    author: 'zova Studio',
    description: 'A smart little mouse learns that a cat is not always a danger.',
    cover: '🐱',
    difficulty: 'Beginner',
    level: 'A1',
    chapters: [
      BookChapter(
        id: 'ch_cat_1',
        title: 'Two neighbours',
        paragraphs: [
          BookParagraph(
            text: 'A little mouse lived in the wall. A cat lived in the kitchen.',
            translation: 'یک موش کوچک در دیوار زندگی میکرد. یک گربه در آشپزخانه زندگی میکرد.',
          ),
          BookParagraph(
            text: 'The cat was fast and the mouse was smart.',
            translation: 'گربه تند بود و موش باهوش بود.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_cat_2',
        title: 'The party',
        paragraphs: [
          BookParagraph(
            text: 'One night, the mouse saw the cat sleeping.',
            translation: 'یک شب، موش گربه را در حال خواب دید.',
          ),
          BookParagraph(
            text: 'The mouse ran to the kitchen and took a piece of cheese.',
            translation: 'موش به آشپزخانه دوید و یک تکه پنیر برداشت.',
          ),
          BookParagraph(
            text: 'The cat woke up and smiled. "Good night, little mouse," she said.',
            translation: 'گربه بیدار شد و لبخند زد. گفت: «شب بخیر، موش کوچولو.»',
          ),
        ],
      ),
    ],
  );

  static const Book _lostKite = Book(
    id: 'book_lost_kite',
    title: 'The Lost Kite',
    author: 'zova Studio',
    description: 'Ali loses his kite in a tree, and his father helps him find a way.',
    cover: '🪁',
    difficulty: 'Beginner',
    level: 'A1',
    chapters: [
      BookChapter(
        id: 'ch_kite_1',
        title: 'A windy day',
        paragraphs: [
          BookParagraph(
            text: 'Ali made a kite with paper and string.',
            translation: 'علی با کاغذ و نخ یک بادبادک ساخت.',
          ),
          BookParagraph(
            text: 'The wind was strong, and the kite flew high in the sky.',
            translation: 'باد شدید بود و بادبادک در آسمان بالا پرواز کرد.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_kite_2',
        title: 'The tree',
        paragraphs: [
          BookParagraph(
            text: 'Suddenly the string broke, and the kite fell in a big tree.',
            translation: 'ناگهان نخ پاره شد و بادبادک روی درخت بزرگ افتاد.',
          ),
          BookParagraph(
            text: 'Ali could not reach it. He was sad.',
            translation: 'علی نتوانست به آن برسد. غمگین بود.',
          ),
          BookParagraph(
            text: 'His father came with a long stick and gave him the kite.',
            translation: 'پدرش با یک چوب بلند آمد و بادبادک را به او داد.',
          ),
          BookParagraph(
            text: 'Ali smiled and ran home to fly the kite again.',
            translation: 'علی لبخند زد و برای پرواز دوبارهی بادبادک به خانه دوید.',
          ),
        ],
      ),
    ],
  );

  static const Book _sundayMarket = Book(
    id: 'book_sunday_market',
    title: 'The Sunday Market',
    author: 'zova Studio',
    description: 'Leila and her grandmother share a busy, colourful morning at the market.',
    cover: '🧺',
    difficulty: 'Elementary',
    level: 'A2',
    chapters: [
      BookChapter(
        id: 'ch_market_1',
        title: 'Early morning',
        paragraphs: [
          BookParagraph(
            text: 'Every Sunday, Leila and her grandmother go to the big market in the old city.',
            translation: 'هر یکشنبه، لیلا و مادربزرگش به بازار بزرگ در شهر قدیمی میروند.',
          ),
          BookParagraph(
            text: 'The market opens at seven, but the best fruits are gone by eight.',
            translation: 'بازار ساعت هفت باز میشود، اما بهترین میوهها تا ساعت هشت تمام میشوند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_market_2',
        title: 'Choosing carefully',
        paragraphs: [
          BookParagraph(
            text: 'Leila checks the price of everything before she buys it.',
            translation: 'لیلا قبل از خرید، قیمت همهچیز را بررسی میکند.',
          ),
          BookParagraph(
            text: 'Today she finds some cheap oranges and a bag of fresh figs.',
            translation: 'امروز او چند پرتقال ارزان و یک کیسه انجیر تازه پیدا میکند.',
          ),
          BookParagraph(
            text: '"This is a good deal," says the seller with a smile.',
            translation: 'فروشنده با لبخند میگوید: «این معاملهی خوبی است.»',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_market_3',
        title: 'A busy day',
        paragraphs: [
          BookParagraph(
            text: 'They drink tea in a small café next to the market.',
            translation: 'آنها در یک کافه کوچک کنار بازار چای مینوشند.',
          ),
          BookParagraph(
            text: 'The sun is warm, the street is full of people, and Leila feels happy.',
            translation: 'خورشید گرم است، خیابان پر از مردم است و لیلا خوشحال است.',
          ),
        ],
      ),
    ],
  );

  static const Book _gardenOfTheOldHouse = Book(
    id: 'book_garden_old_house',
    title: 'The Garden of the Old House',
    author: 'zova Studio',
    description: 'Anna finds a hidden key and brings a forgotten garden back to life.',
    cover: '🌷',
    difficulty: 'Elementary',
    level: 'A2',
    chapters: [
      BookChapter(
        id: 'ch_garden_1',
        title: 'A forgotten place',
        paragraphs: [
          BookParagraph(
            text: 'Behind the old house there is a garden that no one visits anymore.',
            translation: 'پشت خانهی قدیمی باغی است که دیگر کسی به آن سر نمیزند.',
          ),
          BookParagraph(
            text: 'The gate is closed, and the walls are covered with green leaves.',
            translation: 'دروازه بسته است و دیوارها پوشیده از برگهای سبز هستند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_garden_2',
        title: 'The key',
        paragraphs: [
          BookParagraph(
            text: 'One afternoon, Anna finds a small key under the garden gate.',
            translation: 'یک بعدازظهر، آنا یک کلید کوچک زیر دروازهی باغ پیدا میکند.',
          ),
          BookParagraph(
            text: 'The key fits the lock, and the gate opens slowly.',
            translation: 'کلید در قفل جا میافتد و دروازه بهآرامی باز میشود.',
          ),
          BookParagraph(
            text: 'Inside, roses grow along every path.',
            translation: 'داخل باغ، گلهای رز در کنار هر مسیر رشد کردهاند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_garden_3',
        title: 'A promise',
        paragraphs: [
          BookParagraph(
            text: 'Anna visits the garden every day and waters the roses.',
            translation: 'آنا هر روز به باغ میرود و به گلهای رز آب میدهد.',
          ),
          BookParagraph(
            text: 'Soon the garden is full of color again, and the old house looks alive.',
            translation: 'بهزودی باغ دوباره پر از رنگ میشود و خانهی قدیمی زنده به نظر میرسد.',
          ),
        ],
      ),
    ],
  );

  static const Book _letterFromLisbon = Book(
    id: 'book_letter_lisbon',
    title: 'A Letter from Lisbon',
    author: 'zova Studio',
    description: 'An unexpected letter brings a grandfather and grandchild back together.',
    cover: '✉️',
    difficulty: 'Intermediate',
    level: 'B1',
    chapters: [
      BookChapter(
        id: 'ch_letter_1',
        title: 'The envelope',
        paragraphs: [
          BookParagraph(
            text: 'When the letter arrived, I did not know the name on the envelope.',
            translation: 'وقتی نامه رسید، اسم روی پاکت را نمیشناختم.',
          ),
          BookParagraph(
            text: 'It had a stamp from Portugal and a London postmark.',
            translation: 'روی آن تمبر پرتغال و مهر لندن بود.',
          ),
          BookParagraph(
            text: 'My hands were shaking as I opened it.',
            translation: 'وقتی نامه را باز میکردم دستهایم میلرزید.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_letter_2',
        title: 'The story',
        paragraphs: [
          BookParagraph(
            text: 'The letter was from my grandfather, who left Tehran forty years ago.',
            translation: 'نامه از پدربزرگم بود که چهل سال پیش تهران را ترک کرده بود.',
          ),
          BookParagraph(
            text: 'He had settled in Lisbon, opened a small café, and started a new family.',
            translation: 'او در لیسبون ساکن شده بود، کافهی کوچکی باز کرده بود و خانوادهی جدیدی تشکیل داده بود.',
          ),
          BookParagraph(
            text: 'He wrote that he had been looking for us for years.',
            translation: 'نوشته بود که سالهاست دنبال ما میگردد.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_letter_3',
        title: 'The meeting',
        paragraphs: [
          BookParagraph(
            text: 'I booked a flight for the next weekend.',
            translation: 'برای آخر هفتهی بعد بلیت هواپیما رزرو کردم.',
          ),
          BookParagraph(
            text: 'At the airport, an old man with kind eyes was waiting for me.',
            translation: 'در فرودگاه، مردی مسن با چشمان مهربان منتظر من بود.',
          ),
          BookParagraph(
            text: 'We did not need many words. The silence said everything.',
            translation: 'ما به کلمات زیادی نیاز نداشتیم. سکوت همهچیز را میگفت.',
          ),
        ],
      ),
    ],
  );

  static const Book _placeToStart = Book(
    id: 'book_place_to_start',
    title: 'A Place to Start',
    author: 'zova Studio',
    description: 'Mina lands her first job and learns that every big journey begins small.',
    cover: '🏙️',
    difficulty: 'Intermediate',
    level: 'B1',
    chapters: [
      BookChapter(
        id: 'ch_start_1',
        title: 'The interview',
        paragraphs: [
          BookParagraph(
            text: 'Mina had practiced for the interview for weeks.',
            translation: 'مینا هفتهها برای مصاحبه تمرین کرده بود.',
          ),
          BookParagraph(
            text: 'She was nervous, but she knew her skills better than anyone.',
            translation: 'او مضطرب بود، اما مهارتهایش را بهتر از هر کسی میشناخت.',
          ),
          BookParagraph(
            text: 'The manager asked about her experience and her future plans.',
            translation: 'مدیر دربارهی تجربه و برنامههای آیندهاش سؤال کرد.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_start_2',
        title: 'The decision',
        paragraphs: [
          BookParagraph(
            text: 'Two days later, the company sent an email offering her the position.',
            translation: 'دو روز بعد، شرکت ایمیلی فرستاد و آن سمت را به او پیشنهاد کرد.',
          ),
          BookParagraph(
            text: 'She read it three times before she believed it.',
            translation: 'قبل از اینکه باورش کند، سه بار آن را خواند.',
          ),
          BookParagraph(
            text: 'It was a small salary, but it was a place to start.',
            translation: 'حقوق کم بود، اما یک نقطهی شروع بود.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_start_3',
        title: 'The first day',
        paragraphs: [
          BookParagraph(
            text: 'On her first day, Mina met her colleagues and found her desk.',
            translation: 'در روز اول، مینا همکارانش را ملاقات کرد و میز کارش را پیدا کرد.',
          ),
          BookParagraph(
            text: 'She wrote her goals in a notebook: learn, improve, grow.',
            translation: 'اهدافش را در دفتری نوشت: یاد بگیر، بهبود بده، رشد کن.',
          ),
          BookParagraph(
            text: 'Every big journey begins with one small step.',
            translation: 'هر سفر بزرگ با یک قدم کوچک آغاز میشود.',
          ),
        ],
      ),
    ],
  );

  static const Book _lostWallet = Book(
    id: 'book_lost_wallet',
    title: 'The Lost Wallet',
    author: 'zova Studio',
    description: 'Sara finds a wallet on the street and decides to find its owner.',
    cover: '👛',
    difficulty: 'Elementary',
    level: 'A2',
    chapters: [
      BookChapter(
        id: 'ch_wallet_1',
        title: 'On the sidewalk',
        paragraphs: [
          BookParagraph(
            text: 'On the way home from school, Sara saw a black wallet on the sidewalk.',
            translation: 'در راه خانه از مدرسه، سارا یک کیف پول سیاه روی پیادهرو دید.',
          ),
          BookParagraph(
            text: 'She opened it carefully. There was money, a card, and an address.',
            translation: 'با دقت آن را باز کرد. داخلش پول، یک کارت و یک آدرس بود.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_wallet_2',
        title: 'The address',
        paragraphs: [
          BookParagraph(
            text: 'The address was not far away, just two streets from the park.',
            translation: 'آدرس خیلی دور نبود، فقط دو خیابان آن طرفتر از پارک بود.',
          ),
          BookParagraph(
            text: 'Sara walked to the house and rang the bell.',
            translation: 'سارا به آن خانه رفت و زنگ را زد.',
          ),
          BookParagraph(
            text: 'An old woman opened the door and touched her own pocket.',
            translation: 'پیرزنی در را باز کرد و دست به جیب خودش برد.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_wallet_3',
        title: 'A warm thanks',
        paragraphs: [
          BookParagraph(
            text: '"This is my wallet!" she said. "I lost it this morning."',
            translation: 'گفت: «این کیف پول من است! امروز صبح آن را گم کردم.»',
          ),
          BookParagraph(
            text: 'She invited Sara in and gave her a glass of fresh juice.',
            translation: 'او سارا را به خانه دعوت کرد و یک لیوان آبمیوه تازه به او داد.',
          ),
          BookParagraph(
            text: 'Sara felt that a small kind act makes a whole day brighter.',
            translation: 'سارا احساس کرد یک کار کوچک و مهربانانه، کل روز را روشنتر میکند.',
          ),
        ],
      ),
    ],
  );

  static const Book _nightInTheCity = Book(
    id: 'book_night_city',
    title: 'A Night in the City',
    author: 'zova Studio',
    description: 'Two friends explore their hometown by night and see it with new eyes.',
    cover: '🌃',
    difficulty: 'Intermediate',
    level: 'B1',
    chapters: [
      BookChapter(
        id: 'ch_city_1',
        title: 'A different city',
        paragraphs: [
          BookParagraph(
            text: 'Amir had lived in the city all his life, but he had never seen it at night.',
            translation: 'امیر تمام عمرش را در این شهر زندگی کرده بود، اما هرگز آن را شب ندیده بود.',
          ),
          BookParagraph(
            text: 'His friend Leila suggested a walk across the old bridge.',
            translation: 'دوستش لیلا پیشنهاد داد از روی پل قدیمی قدم بزنند.',
          ),
          BookParagraph(
            text: 'The lights of the houses were reflected in the dark water.',
            translation: 'نور خانهها در آب تاریک بازتاب میافتاد.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_city_2',
        title: 'Hidden stories',
        paragraphs: [
          BookParagraph(
            text: 'Every building seemed to carry a story, a memory, a promise.',
            translation: 'به نظر میرسید هر ساختمان یک داستان، یک خاطره و یک قول با خود دارد.',
          ),
          BookParagraph(
            text: 'They passed the old cinema, the market square, and the garden of roses.',
            translation: 'آنها از سینمای قدیمی، میدان بازار و باغ گلهای رز رد شدند.',
          ),
          BookParagraph(
            text: 'Leila told stories about each place that Amir had never heard before.',
            translation: 'لیلا دربارهی هر مکان داستانهایی تعریف کرد که امیر قبلاً هرگز نشنیده بود.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_city_3',
        title: 'New eyes',
        paragraphs: [
          BookParagraph(
            text: 'By midnight, Amir realized he had been blind to his own hometown.',
            translation: 'نزدیک نیمهشب، امیر فهمید که نسبت به زادگاه خودش نابینا بوده است.',
          ),
          BookParagraph(
            text: '"Sometimes you have to change your view to see what was always there."',
            translation: '«گاهی باید دیدت را عوض کنی تا ببینی چه چیزی همیشه آنجا بوده است.»',
          ),
          BookParagraph(
            text: 'They promised to explore a new corner of the city every month.',
            translation: 'آنها قول دادند هر ماه یک گوشهی جدید از شهر را کشف کنند.',
          ),
        ],
      ),
    ],
  );
}
