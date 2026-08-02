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
/// lessons are generated from the bundled master datasets so vocabulary,
/// examples and proficiency levels (A1/A2/B1) stay in one place, and every
/// exercise is translation-free (built from words + example sentences), which
/// makes lessons work offline and for any native language. Each book ships
/// with a curated Persian translation for bilingual reading.
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

    // Exercises are built purely from master facts (words + example
    // sentences), so they work offline and are independent of the learner's
    // native language. The article quiz only appears for gendered nouns
    // (German); every other exercise is language-agnostic.
    final exercises = <Exercise>[
      Exercise(
        type: ExerciseType.flashcard,
        prompt: 'Learn these words',
        words: [for (final w in selected) w.word],
        pairs: {for (final w in selected) w.word: w.example},
        examples: {for (final w in selected) w.word: w.example},
      ),
    ];

    for (final w in selected.take(4)) {
      exercises.add(
        Exercise(
          type: ExerciseType.chooseAnswer,
          prompt: '«${w.example}» — Which word fits this sentence?',
          options: _distractors(
            correct: w.word,
            pool: _wordsOf(dict, level),
            seed: w.word.length + selected.indexOf(w) * 7 + lessonId.length,
          ),
          correctAnswer: w.word,
        ),
      );
    }

    exercises.add(
      Exercise(
        type: ExerciseType.pairs,
        prompt: 'Match each word to its example',
        pairs: {for (final w in selected.take(4)) w.word: w.example},
      ),
    );

    for (final w in selected.skip(4).take(2)) {
      exercises.add(
        Exercise(
          type: ExerciseType.chooseAnswer,
          prompt: '«${w.word}» — Which sentence uses it?',
          options: _distractors(
            correct: w.example,
            pool: _examplesOf(dict, level),
            seed: w.example.length * 3 + lessonId.length + 11,
          ),
          correctAnswer: w.example,
        ),
      );
    }

    for (final w in selected.where((e) => e.gender != null).take(2)) {
      exercises.add(
        Exercise(
          type: ExerciseType.article,
          prompt: '«${w.word}» — Which article does it take?',
          options: const ['der', 'die', 'das'],
          correctAnswer: w.gender,
        ),
      );
    }

    return exercises;
  }

  static List<String> _examplesOf(DictionaryService dict, String level) =>
      dict.entries
          .where((e) => e.level == level)
          .map((e) => e.example)
          .toList();

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
            text: 'In a small house there was a small room. The room was very dark. In the corner stood a little lamp. The lamp was old and a little sad.',
            translation: 'در خانهی کوچکی اتاق کوچکی بود. اتاق خیلی تاریک بود. در گوشه یک چراغ کوچک ایستاده بود. چراغ پیر و کمی غمگین بود.',
          ),
          BookParagraph(
            text: 'The little lamp wanted to shine. But every time it tried, it was afraid. It thought: what if the light is not good enough?',
            translation: 'چراغ کوچک میخواست بدرخشد. اما هر بار که تلاش میکرد، میترسید. فکر میکرد: اگر نور به اندازهی کافی خوب نباشد چه؟',
          ),
          BookParagraph(
            text: 'One evening, a small girl sat in the dark room. She looked at the lamp and smiled. The lamp felt a little braver.',
            translation: 'یک غروب، دختر کوچکی در اتاق تاریک نشست. به چراغ نگاه کرد و لبخند زد. چراغ کمی شجاعتر شد.',
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
            text: 'The little lamp took a deep breath. Then it turned on its light. A warm yellow light filled the room.',
            translation: 'چراغ کوچک نفس عمیقی کشید. بعد چراغش را روشن کرد. نور زرد و گرمی اتاق را پر کرد.',
          ),
          BookParagraph(
            text: 'The room was warm and bright. The bird sang a happy song. The little lamp was very happy.',
            translation: 'اتاق گرم و روشن شد. پرنده آواز شادی خواند. چراغ کوچک خیلی خوشحال بود.',
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
            text: 'The girl did her homework in the lamp\'s light. The old woman knitted in its warm glow.',
            translation: 'دختر تکالیفش را در نور چراغ انجام میداد. پیرزن در روشنایی گرم آن بافتنی میبافت.',
          ),
          BookParagraph(
            text: 'The house was never dark again. And the lamp always remembered: light is best when it is shared.',
            translation: 'خانه دیگر هرگز تاریک نشد. و چراغ همیشه به یاد داشت: نور وقتی بهتر است که تقسیم شود.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_light_4',
        title: 'Light for the street',
        paragraphs: [
          BookParagraph(
            text: 'One night, the lamp saw the street outside. It was dark and empty. People walked past quickly.',
            translation: 'یک شب، چراغ خیابان بیرون را دید. خیابان تاریک و خالی بود. مردم سریع از کنارش رد میشدند.',
          ),
          BookParagraph(
            text: '"Can I help them too?" the lamp asked. "The window is open," said the girl. "Try it."',
            translation: 'چراغ پرسید: «من هم میتوانم به آنها کمک کنم؟» دختر گفت: «پنجره باز است. امتحان کن.»',
          ),
          BookParagraph(
            text: 'The lamp sent its light into the street. The dark road became a little softer. Someone smiled and walked on.',
            translation: 'چراغ نور خود را به خیابان فرستاد. جادهی تاریک کمی روشنتر شد. کسی لبخند زد و به راهش ادامه داد.',
          ),
          BookParagraph(
            text: 'From then on, the little lamp shone for the whole street. A small light, shared with everyone, was the brightest light of all.',
            translation: 'از آن به بعد، چراغ کوچک برای تمام خیابان میدرخشید. یک نور کوچک که با همه تقسیم میشد، روشنترین نور بود.',
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
            text: 'Anna and Ben met at the park gate. The sky was blue and the sun was warm. It was a perfect day for a walk.',
            translation: 'آنا و بن دم دروازهی پارک همدیگر را دیدند. آسمان آبی بود و خورشید گرم. روز عالیای برای قدم زدن بود.',
          ),
          BookParagraph(
            text: '"Let us walk by the lake," said Anna. Ben nodded and smiled. They walked on the soft grass.',
            translation: 'آنا گفت: «بیا کنار دریاچه قدم بزنیم.» بن سر تکان داد و لبخند زد. روی چمن نرم قدم زدند.',
          ),
          BookParagraph(
            text: 'Flowers grew along the path. Anna stopped to smell them. Ben took a photo of the blue sky.',
            translation: 'کنار مسیر گلها رشد کرده بودند. آنا ایستاد تا آنها را بو کند. بن از آسمان آبی عکس گرفت.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_park_2',
        title: 'The little duck',
        paragraphs: [
          BookParagraph(
            text: 'By the lake they saw a little duck with three baby ducks. The baby ducks swam in a line. They looked very funny.',
            translation: 'کنار دریاچه اردکی کوچک با سه جوجهاردک دیدند. جوجهاردکها پشت سر هم شنا میکردند. خیلی بامزه بودند.',
          ),
          BookParagraph(
            text: 'Anna took a piece of bread from her bag and gave it to the ducks. The ducks ate quickly.',
            translation: 'آنا یک تکه نان از کیفهاش درآورد و به اردکها داد. اردکها سریع خوردند.',
          ),
          BookParagraph(
            text: 'One baby duck came very close. "Look at this one," said Anna. "He is not afraid at all."',
            translation: 'یکی از جوجهاردکها خیلی نزدیک آمد. آنا گفت: «به این یکی نگاه کن. اصلاً نمیترسد.»',
          ),
          BookParagraph(
            text: '"That was kind," said Ben. "Let us come back tomorrow." And they did.',
            translation: 'بن گفت: «خیلی مهربان بودی. بیا فردا دوباره بیاییم.» و آنها دوباره آمدند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_park_3',
        title: 'The ice cream',
        paragraphs: [
          BookParagraph(
            text: 'On the way out, they saw a small ice cream shop. Ben bought two ice creams. Anna chose strawberry, Ben chose chocolate.',
            translation: 'در راه برگشت، یک مغازهی کوچک بستنی دیدند. بن دو بستنی خرید. آنا بستنی توتفرنگی انتخاب کرد و بن شکلاتی.',
          ),
          BookParagraph(
            text: 'They sat on a bench in the shade. The ice cream was cold and sweet.',
            translation: 'روی نیمکتی در سایه نشستند. بستنی سرد و شیرین بود.',
          ),
          BookParagraph(
            text: '"This is the best day," said Anna. Ben agreed with a full mouth. They both laughed.',
            translation: 'آنا گفت: «این بهترین روز است.» بن با دهان پر موافقت کرد. هر دو خندیدند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_park_4',
        title: 'Coming back',
        paragraphs: [
          BookParagraph(
            text: 'In the evening, the park was quiet. The birds were going home, and the sun was low.',
            translation: 'عصر، پارک ساکت بود. پرندهها به خانه میرفتند و خورشید پایین آمده بود.',
          ),
          BookParagraph(
            text: 'Anna and Ben walked to the gate one more time. "See you next Sunday?" asked Ben. "Of course," said Anna.',
            translation: 'آنا و بن دوباره به سمت دروازه رفتند. بن پرسید: «یکشنبهی آینده میبینمت؟» آنا گفت: «حتماً.»',
          ),
          BookParagraph(
            text: 'The park stayed in their minds: the ducks, the ice cream, and the warm sun. Some days are simply beautiful.',
            translation: 'پارک در ذهنشان ماند: اردکها، بستنی و خورشید گرم. بعضی روزها به سادگی زیبا هستند.',
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
            text: 'A little mouse lived in the wall. A cat lived in the kitchen. They were neighbours, but they never said hello.',
            translation: 'یک موش کوچک در دیوار زندگی میکرد. یک گربه در آشپزخانه زندگی میکرد. آنها همسایه بودند، اما هیچوقت به هم سلام نمیکردند.',
          ),
          BookParagraph(
            text: 'The cat was fast and the mouse was smart. The cat wanted to catch the mouse. The mouse always ran away.',
            translation: 'گربه تند بود و موش باهوش بود. گربه میخواست موش را بگیرد. موش همیشه فرار میکرد.',
          ),
          BookParagraph(
            text: 'Every night, the mouse looked at the cheese in the kitchen. It was always just a little too far.',
            translation: 'هر شب، موش به پنیر آشپزخانه نگاه میکرد. پنیر همیشه فقط کمی دور بود.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_cat_2',
        title: 'The party',
        paragraphs: [
          BookParagraph(
            text: 'One night, the mouse saw the cat sleeping. The cat looked calm and quiet.',
            translation: 'یک شب، موش گربه را در حال خواب دید. گربه آرام و ساکت به نظر میرسید.',
          ),
          BookParagraph(
            text: 'The mouse ran to the kitchen and took a piece of cheese. But the cheese made a noise: it was too big.',
            translation: 'موش به آشپزخانه دوید و یک تکه پنیر برداشت. اما پنیر سر و صدا کرد: خیلی بزرگ بود.',
          ),
          BookParagraph(
            text: 'The cat opened one eye. The mouse froze. Neither of them moved for a long moment.',
            translation: 'گربه یک چشمش را باز کرد. موش خشکش زد. هیچکدام برای لحظهای طولانی تکان نخوردند.',
          ),
          BookParagraph(
            text: 'The cat woke up and smiled. "Good night, little mouse," she said. "Enjoy the cheese."',
            translation: 'گربه بیدار شد و لبخند زد. گفت: «شب بخیر، موش کوچولو. از پنیر لذت ببر.»',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_cat_3',
        title: 'The best friends',
        paragraphs: [
          BookParagraph(
            text: 'After that night, everything changed. The cat and the mouse shared the kitchen.',
            translation: 'بعد از آن شب، همهچیز عوض شد. گربه و موش آشپزخانه را با هم تقسیم کردند.',
          ),
          BookParagraph(
            text: 'Every evening they shared one piece of cheese. Sometimes they talked about their day.',
            translation: 'هر شب یک تکه پنیر را با هم میخوردند. گاهی دربارهی روزشان حرف میزدند.',
          ),
          BookParagraph(
            text: 'The mouse learned that a cat is not always a danger. And the cat learned that a mouse can be a friend.',
            translation: 'موش یاد گرفت که گربه همیشه خطر نیست. و گربه یاد گرفت که موش میتواند دوست باشد.',
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
            text: 'Ali made a kite with paper and string. He painted it blue like the sky.',
            translation: 'علی با کاغذ و نخ یک بادبادک ساخت. آن را مثل آسمان آبی رنگ کرد.',
          ),
          BookParagraph(
            text: 'The wind was strong, and the kite flew high in the sky. Ali held the string and ran.',
            translation: 'باد شدید بود و بادبادک در آسمان بالا پرواز کرد. علی نخ را گرفت و دوید.',
          ),
          BookParagraph(
            text: 'The kite danced in the air. Ali laughed and shouted, "Look at my kite!"',
            translation: 'بادبادک در هوا میرقصید. علی خندید و فریاد زد: «به بادبادک من نگاه کن!»',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_kite_2',
        title: 'The tree',
        paragraphs: [
          BookParagraph(
            text: 'Suddenly the string broke, and the kite fell in a big tree. It hung between the branches.',
            translation: 'ناگهان نخ پاره شد و بادبادک روی درخت بزرگ افتاد. بین شاخهها گیر کرد.',
          ),
          BookParagraph(
            text: 'Ali could not reach it. He jumped, but the kite was too high. He was sad.',
            translation: 'علی نتوانست به آن برسد. پرید، اما بادبادک خیلی بالا بود. غمگین بود.',
          ),
          BookParagraph(
            text: 'His father came with a long stick. He pushed the kite with the stick, and it fell down safely.',
            translation: 'پدرش با یک چوب بلند آمد. با چوب بادبادک را هل داد و بادبادک به سلامت پایین افتاد.',
          ),
          BookParagraph(
            text: 'Ali held his kite again. "Thank you, Baba," he said. "I was afraid I lost it forever."',
            translation: 'علی دوباره بادبادکش را گرفت. گفت: «ممنون، بابا. میترسیدم برای همیشه گمش کرده باشم.»',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_kite_3',
        title: 'A new kite',
        paragraphs: [
          BookParagraph(
            text: 'That evening, Ali and his father made a new string. They made it long and strong.',
            translation: 'آن عصر، علی و پدرش یک نخ جدید درست کردند. نخ را بلند و محکم ساختند.',
          ),
          BookParagraph(
            text: 'The next morning, the kite flew even higher. Ali ran in the field and smiled.',
            translation: 'صبح روز بعد، بادبادک حتی بالاتر پرواز کرد. علی در مزرعه دوید و لبخند زد.',
          ),
          BookParagraph(
            text: 'When the string broke again, Ali did not cry. He knew how to fix it now. A good day teaches you something.',
            translation: 'وقتی نخ دوباره پاره شد، علی گریه نکرد. حالا میدانست چطور آن را درست کند. یک روز خوب چیزی به تو یاد میدهد.',
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
            text: 'Every Sunday, Leila and her grandmother go to the big market in the old city. They leave home before the sun is fully up.',
            translation: 'هر یکشنبه، لیلا و مادربزرگش به بازار بزرگ در شهر قدیمی میروند. قبل از اینکه خورشید کاملاً بلند شود، از خانه بیرون میروند.',
          ),
          BookParagraph(
            text: 'The market opens at seven, but the best fruits are gone by eight. So they always walk fast on the way there.',
            translation: 'بازار ساعت هفت باز میشود، اما بهترین میوهها تا ساعت هشت تمام میشوند. به همین دلیل همیشه تند راه میروند.',
          ),
          BookParagraph(
            text: 'The streets smell of bread and flowers. The sellers call their prices in loud, friendly voices.',
            translation: 'خیابانها بوی نان و گل میدهند. فروشندهها قیمتها را با صدای بلند و مهربان صدا میزنند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_market_2',
        title: 'Choosing carefully',
        paragraphs: [
          BookParagraph(
            text: 'Leila checks the price of everything before she buys it. Her grandmother taught her to look at both sides of the fruit.',
            translation: 'لیلا قبل از خرید، قیمت همهچیز را بررسی میکند. مادربزرگش به او یاد داده است به هر دو طرف میوه نگاه کند.',
          ),
          BookParagraph(
            text: 'Today she finds some cheap oranges and a bag of fresh figs. The figs are soft and smell like summer.',
            translation: 'امروز او چند پرتقال ارزان و یک کیسه انجیر تازه پیدا میکند. انجیرها نرم هستند و بوی تابستان میدهند.',
          ),
          BookParagraph(
            text: '"This is a good deal," says the seller with a smile. He puts the figs in a paper bag and thanks her.',
            translation: 'فروشنده با لبخند میگوید: «این معاملهی خوبی است.» او انجیرها را در کیسهی کاغذی میگذارد و از او تشکر میکند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_market_3',
        title: 'A busy day',
        paragraphs: [
          BookParagraph(
            text: 'After the fruit, they buy bread from the old bakery. The bread is still warm from the oven.',
            translation: 'بعد از میوه، از نانوایی قدیمی نان میخرند. نان هنوز از تنور گرم است.',
          ),
          BookParagraph(
            text: 'They drink tea in a small café next to the market. The tea is sweet, and the glasses are small and full.',
            translation: 'آنها در یک کافه کوچک کنار بازار چای مینوشند. چای شیرین است و استکانها کوچک و پر هستند.',
          ),
          BookParagraph(
            text: 'The sun is warm, the street is full of people, and Leila feels happy. She loves the noise and the colours.',
            translation: 'خورشید گرم است، خیابان پر از مردم است و لیلا خوشحال است. او عاشق سر و صدا و رنگهاست.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_market_4',
        title: 'Home again',
        paragraphs: [
          BookParagraph(
            text: 'On the way home, the bag feels heavy, but Leila does not mind. She already plans the meal for lunch.',
            translation: 'در راه خانه، کیسه سنگین است، اما لیلا ناراحت نیست. او از حالا برای ناهار برنامهریزی میکند.',
          ),
          BookParagraph(
            text: 'Her grandmother rests on a bench for a moment. "Come," she says. "Good things are worth a slow walk."',
            translation: 'مادربزرگش لحظهای روی نیمکت استراحت میکند. میگوید: «بیا. چیزهای خوب ارزش یک قدم زدن آرام را دارند.»',
          ),
          BookParagraph(
            text: 'At home, the table is full of colours: oranges, figs, bread and flowers. The Sunday market makes their week brighter.',
            translation: 'در خانه، میز پر از رنگ است: پرتقال، انجیر، نان و گل. بازار یکشنبه هفتهشان را روشنتر میکند.',
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
            text: 'Behind the old house there is a garden that no one visits anymore. The house has been empty for many years.',
            translation: 'پشت خانهی قدیمی باغی است که دیگر کسی به آن سر نمیزند. خانه سالهاست خالی است.',
          ),
          BookParagraph(
            text: 'The gate is closed, and the walls are covered with green leaves. In summer, the roses grow wild and tall.',
            translation: 'دروازه بسته است و دیوارها پوشیده از برگهای سبز هستند. در تابستان، گلهای رز وحشی و بلند میشوند.',
          ),
          BookParagraph(
            text: 'People say the garden belonged to a painter. They say he planted a rose for every colour of his paint.',
            translation: 'مردم میگویند این باغ متعلق به یک نقاش بوده. میگویند برای هر رنگ از رنگهایش، یک گل رز کاشته بود.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_garden_2',
        title: 'The key',
        paragraphs: [
          BookParagraph(
            text: 'One afternoon, Anna finds a small key under the garden gate. The key is old and a little green from rain.',
            translation: 'یک بعدازظهر، آنا یک کلید کوچک زیر دروازهی باغ پیدا میکند. کلید قدیمی است و از باران کمی سبز شده است.',
          ),
          BookParagraph(
            text: 'The key fits the lock, and the gate opens slowly. The old wood makes a long, soft sound.',
            translation: 'کلید در قفل جا میافتد و دروازه بهآرامی باز میشود. چوب قدیمی صدای بلند و نرمی میدهد.',
          ),
          BookParagraph(
            text: 'Inside, roses grow along every path. Bees move from flower to flower. The air is warm and full of perfume.',
            translation: 'داخل باغ، گلهای رز در کنار هر مسیر رشد کردهاند. زنبورها از گلی به گل دیگر میروند. هوا گرم و پر از عطر است.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_garden_3',
        title: 'A promise',
        paragraphs: [
          BookParagraph(
            text: 'Anna visits the garden every day and waters the roses. She cleans the paths and cuts the dry leaves.',
            translation: 'آنا هر روز به باغ میرود و به گلهای رز آب میدهد. مسیرها را تمیز میکند و برگهای خشک را میچیند.',
          ),
          BookParagraph(
            text: 'The old painter\'s story stays in her mind. She imagines him standing where she stands, watching the colours.',
            translation: 'داستان نقاش پیر در ذهنش میماند. او او را در همان جایی که خودش ایستاده تصور میکند که به رنگها نگاه میکند.',
          ),
          BookParagraph(
            text: 'Soon the garden is full of color again, and the old house looks alive. Even the closed windows seem to smile.',
            translation: 'بهزودی باغ دوباره پر از رنگ میشود و خانهی قدیمی زنده به نظر میرسد. حتی پنجرههای بسته هم به نظر میرسد لبخند میزنند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_garden_4',
        title: 'Spring',
        paragraphs: [
          BookParagraph(
            text: 'One day, a letter comes to the old house. It is from the painter\'s family, who now live far away.',
            translation: 'یک روز، نامهای به خانهی قدیمی میرسد. نامه از خانوادهی نقاش است که حالا خیلی دور زندگی میکنند.',
          ),
          BookParagraph(
            text: 'Anna writes back and sends them photographs of the garden. "Your roses are beautiful again," she writes.',
            translation: 'آنا جواب میدهد و عکسهای باغ را برایشان میفرستد. مینویسد: «گلهای رز شما دوباره زیبا هستند.»',
          ),
          BookParagraph(
            text: 'In spring, the family comes to visit. The children run between the flowers, and the old woman cries happy tears.',
            translation: 'در بهار، خانواده به دیدن میآید. بچهها بین گلها میدوند و پیرزن اشک شوق میریزد.',
          ),
          BookParagraph(
            text: 'The garden, once forgotten, becomes a place where people gather again. Sometimes a small key opens a whole new world.',
            translation: 'باغ که زمانی فراموش شده بود، دوباره جایی میشود که مردم در آن جمع میشوند. گاهی یک کلید کوچک یک دنیای تازه باز میکند.',
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
            text: 'When the letter arrived, I did not know the name on the envelope. It was old handwriting, slow and careful.',
            translation: 'وقتی نامه رسید، اسم روی پاکت را نمیشناختم. دستخط قدیمی بود، آهسته و دقیق.',
          ),
          BookParagraph(
            text: 'It had a stamp from Portugal and a London postmark. It had travelled across two countries before it reached me.',
            translation: 'روی آن تمبر پرتغال و مهر لندن بود. قبل از اینکه به من برسد، از دو کشور عبور کرده بود.',
          ),
          BookParagraph(
            text: 'My hands were shaking as I opened it. Inside was a photo of an old man standing in front of a small café.',
            translation: 'وقتی نامه را باز میکردم دستهایم میلرزید. داخلش عکسی بود از مردی مسن که جلوی یک کافهی کوچک ایستاده بود.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_letter_2',
        title: 'The story',
        paragraphs: [
          BookParagraph(
            text: 'The letter was from my grandfather, who left Tehran forty years ago. My mother never spoke about him.',
            translation: 'نامه از پدربزرگم بود که چهل سال پیش تهران را ترک کرده بود. مادرم هرگز دربارهی او حرف نمیزد.',
          ),
          BookParagraph(
            text: 'He had settled in Lisbon, opened a small café, and started a new family. He had a daughter, two sons, and six grandchildren.',
            translation: 'او در لیسبون ساکن شده بود، کافهی کوچکی باز کرده بود و خانوادهی جدیدی تشکیل داده بود. یک دختر، دو پسر و شش نوه داشت.',
          ),
          BookParagraph(
            text: 'He wrote that he had been looking for us for years. He wrote that every night, before closing the café, he said my name.',
            translation: 'نوشته بود که سالهاست دنبال ما میگردد. نوشته بود هر شب، قبل از بستن کافه، اسم من را میگوید.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_letter_3',
        title: 'The meeting',
        paragraphs: [
          BookParagraph(
            text: 'I booked a flight for the next weekend. I told no one, not even my mother. I needed to see him first.',
            translation: 'برای آخر هفتهی بعد بلیت هواپیما رزرو کردم. به کسی نگفتم، حتی به مادرم. اول باید او را میدیدم.',
          ),
          BookParagraph(
            text: 'At the airport, an old man with kind eyes was waiting for me. He held a small box of saffron cake.',
            translation: 'در فرودگاه، مردی مسن با چشمان مهربان منتظر من بود. یک جعبهی کوچک کیک زعفرانی در دست داشت.',
          ),
          BookParagraph(
            text: 'We did not need many words. The silence said everything. Forty years disappeared between two cups of tea.',
            translation: 'ما به کلمات زیادی نیاز نداشتیم. سکوت همهچیز را میگفت. چهل سال بین دو استکان چای ناپدید شد.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_letter_4',
        title: 'The café',
        paragraphs: [
          BookParagraph(
            text: 'The café was small and warm, with old photos on every wall. One wall was full of pictures of people who had left Tehran.',
            translation: 'کافه کوچک و گرم بود و روی هر دیوارش عکسهای قدیمی بود. یکی از دیوارها پر بود از عکسهای کسانی که تهران را ترک کرده بودند.',
          ),
          BookParagraph(
            text: 'He pointed to a corner seat. "I kept this chair for you," he said. "I always believed you would come."',
            translation: 'او به یک صندلی در گوشه اشاره کرد و گفت: «این صندلی را برای تو نگه داشتهام. همیشه باور داشتم که میآیی.»',
          ),
          BookParagraph(
            text: 'That evening, I called my mother. She listened, and then she cried. "Tell him I remember the saffron cake," she said.',
            translation: 'آن شب به مادرم زنگ زدم. او گوش داد و بعد گریه کرد. گفت: «به او بگو کیک زعفرانی را به یاد دارم.»',
          ),
          BookParagraph(
            text: 'Some letters change nothing, and some change everything. That one changed us all.',
            translation: 'بعضی نامهها هیچچیز را عوض نمیکنند و بعضی همهچیز را. آن نامه همهی ما را عوض کرد.',
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
            text: 'Mina had practiced for the interview for weeks. She had learned the company\'s history and practiced her answers in front of the mirror.',
            translation: 'مینا هفتهها برای مصاحبه تمرین کرده بود. تاریخچهی شرکت را یاد گرفته بود و جوابهایش را جلوی آینه تمرین کرده بود.',
          ),
          BookParagraph(
            text: 'She was nervous, but she knew her skills better than anyone. She had rebuilt her life once before, and she could do it again.',
            translation: 'او مضطرب بود، اما مهارتهایش را بهتر از هر کسی میشناخت. او یک بار دیگر زندگیاش را بازسازی کرده بود و میتوانست دوباره این کار را بکند.',
          ),
          BookParagraph(
            text: 'The manager asked about her experience and her future plans. Mina answered with a steady voice and honest eyes.',
            translation: 'مدیر دربارهی تجربه و برنامههای آیندهاش سؤال کرد. مینا با صدایی محکم و چشمانی صادق جواب داد.',
          ),
          BookParagraph(
            text: '"Why do you want this job?" the manager asked. Mina thought for a moment. "Because I have something to prove to myself," she said.',
            translation: 'مدیر پرسید: «چرا این شغل را میخواهید؟» مینا لحظهای فکر کرد و گفت: «چون چیزی دارم که باید به خودم ثابت کنم.»',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_start_2',
        title: 'The decision',
        paragraphs: [
          BookParagraph(
            text: 'Two days later, the company sent an email offering her the position. She read it three times before she believed it.',
            translation: 'دو روز بعد، شرکت ایمیلی فرستاد و آن سمت را به او پیشنهاد کرد. قبل از اینکه باورش کند، سه بار آن را خواند.',
          ),
          BookParagraph(
            text: 'It was a small salary, but it was a place to start. Her friends said she should ask for more. She said she would, later.',
            translation: 'حقوق کم بود، اما یک نقطهی شروع بود. دوستانش گفتند باید بیشتر بخواهد. او گفت بعداً خواهد خواست.',
          ),
          BookParagraph(
            text: 'That night, she sat on her balcony and looked at the city lights. She had no car, no office, no title. She had a chance.',
            translation: 'آن شب روی بالکن نشست و به چراغهای شهر نگاه کرد. ماشین نداشت، دفتر کار نداشت، عنوان نداشت. یک فرصت داشت.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_start_3',
        title: 'The first day',
        paragraphs: [
          BookParagraph(
            text: 'On her first day, Mina met her colleagues and found her desk. The desk was small and had a broken lamp. She did not mind.',
            translation: 'در روز اول، مینا همکارانش را ملاقات کرد و میز کارش را پیدا کرد. میز کوچک بود و یک چراغ خراب داشت. ناراحت نبود.',
          ),
          BookParagraph(
            text: 'She wrote her goals in a notebook: learn, improve, grow. She placed the notebook where she could always see it.',
            translation: 'اهدافش را در دفتری نوشت: یاد بگیر، بهبود بده، رشد کن. دفتر را جایی گذاشت که همیشه بتواند آن را ببیند.',
          ),
          BookParagraph(
            text: 'At lunch, a colleague invited her to sit with the team. She was the last to arrive and the first to laugh.',
            translation: 'سر ناهار، یکی از همکاران او را دعوت کرد کنار تیم بنشیند. او آخرین کسی بود که رسید و اولین کسی که خندید.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_start_4',
        title: 'The small step',
        paragraphs: [
          BookParagraph(
            text: 'By the end of the week, Mina had fixed the lamp, learned the names of everyone, and finished her first small project.',
            translation: 'تا آخر هفته، مینا چراغ را تعمیر کرده بود، اسم همه را یاد گرفته بود و اولین پروژهی کوچکش را تمام کرده بود.',
          ),
          BookParagraph(
            text: 'Her manager stopped by her desk. "Good work," he said. "There is a bigger project coming. I want you on it."',
            translation: 'مدیرش کنار میزش ایستاد و گفت: «کار خوبی بود. یک پروژهی بزرگتر در راه است. میخواهم تو در آن باشی.»',
          ),
          BookParagraph(
            text: 'Mina did not scream. She just smiled and said thank you. Then she opened her notebook and wrote one more word: next.',
            translation: 'مینا جیغ نزد. فقط لبخند زد و تشکر کرد. بعد دفترش را باز کرد و یک کلمهی دیگر نوشت: بعدی.',
          ),
          BookParagraph(
            text: 'Every big journey begins with one small step. And the second step is already a little easier.',
            translation: 'هر سفر بزرگ با یک قدم کوچک آغاز میشود. و قدم دوم کمی راحتتر است.',
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
            text: 'On the way home from school, Sara saw a black wallet on the sidewalk. It lay under a bench, half hidden by a dry leaf.',
            translation: 'در راه خانه از مدرسه، سارا یک کیف پول سیاه روی پیادهرو دید. زیر یک نیمکت افتاده بود و نیمی از آن زیر برگ خشکی پنهان بود.',
          ),
          BookParagraph(
            text: 'She opened it carefully. There was money, a card, and an address. The card had a photo of an old woman smiling.',
            translation: 'با دقت آن را باز کرد. داخلش پول، یک کارت و یک آدرس بود. روی کارت عکسی از پیرزنی خندان بود.',
          ),
          BookParagraph(
            text: 'Sara looked around. The street was quiet. She could walk away and no one would know. But her mother\'s voice stopped her.',
            translation: 'سارا به اطراف نگاه کرد. خیابان خلوت بود. میتوانست برود و کسی نفهمد. اما صدای مادرش او را نگه داشت.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_wallet_2',
        title: 'The address',
        paragraphs: [
          BookParagraph(
            text: 'The address was not far away, just two streets from the park. Sara knew the neighbourhood from her walks with her father.',
            translation: 'آدرس خیلی دور نبود، فقط دو خیابان آن طرفتر از پارک بود. سارا محله را از پیادهرویهایش با پدرش میشناخت.',
          ),
          BookParagraph(
            text: 'Sara walked to the house and rang the bell. The paint on the door was old, and the garden was full of yellow flowers.',
            translation: 'سارا به آن خانه رفت و زنگ را زد. رنگ در قدیمی بود و باغچه پر از گلهای زرد بود.',
          ),
          BookParagraph(
            text: 'An old woman opened the door and touched her own pocket. "My wallet," she whispered. "I thought I lost it on the bus."',
            translation: 'پیرزنی در را باز کرد و دست به جیب خودش برد. زمزمه کرد: «کیف پولم. فکر میکردم توی اتوبوس گمش کردهام.»',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_wallet_3',
        title: 'A warm thanks',
        paragraphs: [
          BookParagraph(
            text: '"This is my wallet!" she said. "I lost it this morning." She looked at the money and counted it with shaking hands.',
            translation: 'گفت: «این کیف پول من است! امروز صبح آن را گم کردم.» به پولها نگاه کرد و با دستهای لرزان آنها را شمرد.',
          ),
          BookParagraph(
            text: 'She invited Sara in and gave her a glass of fresh juice. Then she brought a small box of cookies.',
            translation: 'او سارا را به خانه دعوت کرد و یک لیوان آبمیوه تازه به او داد. بعد یک جعبهی کوچک کلوچه آورد.',
          ),
          BookParagraph(
            text: '"You could have kept it," the woman said. "Why did you bring it back?" Sara smiled. "Because it was yours," she said simply.',
            translation: 'پیرزن گفت: «میتوانستی نگهش داری. چرا برگرداندی؟» سارا ساده گفت: «چون مال شما بود.»',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_wallet_4',
        title: 'A good day',
        paragraphs: [
          BookParagraph(
            text: 'The old woman opened a drawer and took out an old photo. It was the same photo from the card, but older and softer.',
            translation: 'پیرزن کشویی را باز کرد و یک عکس قدیمی بیرون آورد. همان عکس روی کارت بود، اما قدیمیتر و نرمتر.',
          ),
          BookParagraph(
            text: '"My husband gave me this wallet thirty years ago," she said. "He passed away last winter. This wallet is all I have left of him."',
            translation: 'گفت: «شوهرم سی سال پیش این کیف پول را به من داد. زمستان گذشته از دنیا رفت. این کیف پول تنها چیزی است که از او برایم مانده است.»',
          ),
          BookParagraph(
            text: 'Sara felt that a small kind act makes a whole day brighter. She walked home with a warm heart and a box of cookies.',
            translation: 'سارا احساس کرد یک کار کوچک و مهربانانه، کل روز را روشنتر میکند. با قلبی گرم و یک جعبه کلوچه به خانه رفت.',
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
            text: 'Amir had lived in the city all his life, but he had never seen it at night. For him, the city was traffic, work and short days.',
            translation: 'امیر تمام عمرش را در این شهر زندگی کرده بود، اما هرگز آن را شب ندیده بود. برای او، شهر ترافیک، کار و روزهای کوتاه بود.',
          ),
          BookParagraph(
            text: 'His friend Leila suggested a walk across the old bridge. "You think you know this place," she said. "Wait until you see it dark."',
            translation: 'دوستش لیلا پیشنهاد داد از روی پل قدیمی قدم بزنند. گفت: «فکر میکنی اینجا را میشناسی. صبر کن تا تاریکیاش را ببینی.»',
          ),
          BookParagraph(
            text: 'The lights of the houses were reflected in the dark water. The city looked smaller, softer, almost friendly.',
            translation: 'نور خانهها در آب تاریک بازتاب میافتاد. شهر کوچکتر، نرمتر و تقریباً مهربانتر به نظر میرسید.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_city_2',
        title: 'Hidden stories',
        paragraphs: [
          BookParagraph(
            text: 'Every building seemed to carry a story, a memory, a promise. Amir had passed these walls a thousand times without looking at them.',
            translation: 'به نظر میرسید هر ساختمان یک داستان، یک خاطره و یک قول با خود دارد. امیر هزار بار از کنار این دیوارها رد شده بود بدون اینکه به آنها نگاه کند.',
          ),
          BookParagraph(
            text: 'They passed the old cinema, the market square, and the garden of roses. Leila stopped in front of every door.',
            translation: 'آنها از سینمای قدیمی، میدان بازار و باغ گلهای رز رد شدند. لیلا جلوی هر در میایستاد.',
          ),
          BookParagraph(
            text: 'Leila told stories about each place that Amir had never heard before. About the tailor who could hear the rain, and the baker who sang to his bread.',
            translation: 'لیلا دربارهی هر مکان داستانهایی تعریف کرد که امیر قبلاً هرگز نشنیده بود. دربارهی خیاطی که صدای باران را میشنید و نانوایی که برای نانش آواز میخواند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_city_3',
        title: 'The bridge at midnight',
        paragraphs: [
          BookParagraph(
            text: 'At midnight they reached the old bridge. The streetlights drew circles of gold on the stones.',
            translation: 'نزدیک نیمهشب به پل قدیمی رسیدند. چراغهای خیابان دایرههای طلایی روی سنگها کشیده بودند.',
          ),
          BookParagraph(
            text: 'Leila leaned on the railing. "They say this bridge listens," she said. "If you tell it a wish, the river takes it to the sea."',
            translation: 'لیلا به نرده تکیه داد و گفت: «میگویند این پل گوش میدهد. اگر آرزویی بهش بگویی، رودخانه آن را به دریا میبرد.»',
          ),
          BookParagraph(
            text: 'Amir closed his eyes and made a wish. He did not tell Leila what it was. Some wishes lose their power when they are spoken.',
            translation: 'امیر چشمهایش را بست و آرزویی کرد. به لیلا نگفت آن آرزو چیست. بعضی آرزوها وقتی گفته میشوند قدرتشان را از دست میدهند.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_city_4',
        title: 'New eyes',
        paragraphs: [
          BookParagraph(
            text: 'By the time they walked home, Amir realized he had been blind to his own hometown. He had seen the buildings but never the light.',
            translation: 'تا وقتی به خانه برگشتند، امیر فهمید که نسبت به زادگاه خودش نابینا بوده است. ساختمانها را دیده بود اما نور را هرگز.',
          ),
          BookParagraph(
            text: '"Sometimes you have to change your view to see what was always there," said Leila.',
            translation: 'لیلا گفت: «گاهی باید دیدت را عوض کنی تا ببینی چه چیزی همیشه آنجا بوده است.»',
          ),
          BookParagraph(
            text: 'They promised to explore a new corner of the city every month. To walk a street they had never walked, to read a wall like a page.',
            translation: 'آنها قول دادند هر ماه یک گوشهی جدید از شهر را کشف کنند. در خیابانی قدم بزنند که هیچوقت نرفتهاند، و دیواری را مثل صفحهی کتاب بخوانند.',
          ),
          BookParagraph(
            text: 'Amir knew that from that night on, the city would never feel the same again. A night walk had changed his whole map of home.',
            translation: 'امیر میدانست از آن شب به بعد، شهر دیگر برایش مثل قبل نخواهد بود. یک قدم زدن شبانه، تمام نقشهی خانهاش را تغییر داده بود.',
          ),
        ],
      ),
    ],
  );
}
