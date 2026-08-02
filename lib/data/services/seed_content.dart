import '../models/book.dart';
import '../models/course.dart';
import '../models/exercise.dart';

/// Original educational content bundled with the app.
///
/// Everything in here is written from scratch for zova. In production this
/// content can be moved to the backend and fetched per course; the models are
/// already JSON-serialisable for exactly that purpose.
abstract final class SeedContent {
  static final List<Course> courses = [_englishStarter];

  static final List<Book> books = [_littleLight, _walkInThePark];

  // ---------------------------------------------------------------------------
  // Courses
  // ---------------------------------------------------------------------------

  static const Course _englishStarter = Course(
    id: 'course_english_starter',
    title: 'English Starter',
    description:
        'Your first steps in English: greetings, introductions and everyday words.',
    color: 0xFF3D7BFF,
    levels: [
      CourseLevel(
        id: 'level_greetings',
        title: 'Greetings',
        lessons: [
          Lesson(
            id: 'lesson_say_hello',
            title: 'Say hello',
            icon: '👋',
            exercises: [
              Exercise(
                type: ExerciseType.flashcard,
                prompt: 'Learn these words',
                words: ['hello', 'goodbye', 'please', 'thank you'],
                pairs: {
                  'hello': 'hallo',
                  'goodbye': 'auf Wiedersehen',
                  'please': 'bitte',
                  'thank you': 'danke',
                },
              ),
              Exercise(
                type: ExerciseType.chooseAnswer,
                prompt: 'What does "hello" mean?',
                options: ['Hallo', 'Auf Wiedersehen', 'Bitte', 'Danke'],
                correctAnswer: 'Hallo',
              ),
              Exercise(
                type: ExerciseType.chooseAnswer,
                prompt: 'What does "goodbye" mean?',
                options: ['Hallo', 'Bitte', 'Auf Wiedersehen', 'Ja'],
                correctAnswer: 'Auf Wiedersehen',
              ),
              Exercise(
                type: ExerciseType.translate,
                prompt: 'Translate "please"',
                correctAnswer: 'bitte',
              ),
            ],
          ),
          Lesson(
            id: 'lesson_polite_words',
            title: 'Polite words',
            icon: '🙏',
            exercises: [
              Exercise(
                type: ExerciseType.flashcard,
                prompt: 'Learn these words',
                words: ['yes', 'no', 'friend', 'family'],
                pairs: {
                  'yes': 'ja',
                  'no': 'nein',
                  'friend': 'Freund',
                  'family': 'Familie',
                },
              ),
              Exercise(
                type: ExerciseType.translate,
                prompt: 'Translate "yes"',
                correctAnswer: 'ja',
              ),
              Exercise(
                type: ExerciseType.chooseAnswer,
                prompt: 'What does "friend" mean?',
                options: ['Freund', 'Haus', 'Schule', 'Name'],
                correctAnswer: 'Freund',
              ),
              Exercise(
                type: ExerciseType.pairs,
                prompt: 'Match the pairs',
                pairs: {
                  'hello': 'hallo',
                  'yes': 'ja',
                  'no': 'nein',
                  'family': 'Familie',
                },
              ),
            ],
          ),
        ],
      ),
      CourseLevel(
        id: 'level_everyday',
        title: 'Everyday words',
        lessons: [
          Lesson(
            id: 'lesson_around_us',
            title: 'Around us',
            icon: '🏠',
            exercises: [
              Exercise(
                type: ExerciseType.flashcard,
                prompt: 'Learn these words',
                words: ['water', 'food', 'house', 'school'],
                pairs: {
                  'water': 'Wasser',
                  'food': 'Essen',
                  'house': 'Haus',
                  'school': 'Schule',
                },
              ),
              Exercise(
                type: ExerciseType.chooseAnswer,
                prompt: 'What does "water" mean?',
                options: ['Wasser', 'Essen', 'Haus', 'Buch'],
                correctAnswer: 'Wasser',
              ),
              Exercise(
                type: ExerciseType.pairs,
                prompt: 'Match the pairs',
                pairs: {
                  'house': 'Haus',
                  'school': 'Schule',
                  'food': 'Essen',
                  'book': 'Buch',
                },
              ),
              Exercise(
                type: ExerciseType.translate,
                prompt: 'Translate "book"',
                correctAnswer: 'buch',
              ),
            ],
          ),
          Lesson(
            id: 'lesson_numbers',
            title: 'First numbers',
            icon: '🔢',
            exercises: [
              Exercise(
                type: ExerciseType.flashcard,
                prompt: 'Learn these words',
                words: ['one', 'two', 'three'],
                pairs: {
                  'one': 'eins',
                  'two': 'zwei',
                  'three': 'drei',
                },
              ),
              Exercise(
                type: ExerciseType.chooseAnswer,
                prompt: 'What does "two" mean?',
                options: ['Eins', 'Zwei', 'Drei', 'Bitte'],
                correctAnswer: 'Zwei',
              ),
              Exercise(
                type: ExerciseType.pairs,
                prompt: 'Match the numbers',
                pairs: {
                  'one': 'eins',
                  'two': 'zwei',
                  'three': 'drei',
                  'day': 'Tag',
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );

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
    chapters: [
      BookChapter(
        id: 'ch_light_1',
        title: 'The dark room',
        paragraphs: [
          BookParagraph(
            text: 'In a small house there was a small room. The room was very dark. In the corner stood a little lamp.',
          ),
          BookParagraph(
            text: 'The little lamp wanted to shine. But every time it tried, it was afraid.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_light_2',
        title: 'One little step',
        paragraphs: [
          BookParagraph(
            text: 'One day a bird came to the window. "Shine," said the bird. "The night is cold without light."',
          ),
          BookParagraph(
            text: 'The little lamp took a deep breath. Then it turned on its light.',
          ),
          BookParagraph(
            text: 'The room was warm and bright. The bird sang a happy song.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_light_3',
        title: 'Every night',
        paragraphs: [
          BookParagraph(
            text: 'From that day on, the little lamp shone every night. It was no longer afraid.',
          ),
          BookParagraph(
            text: 'The house was never dark again. And the lamp always remembered: light is best when it is shared.',
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
    chapters: [
      BookChapter(
        id: 'ch_park_1',
        title: 'A sunny day',
        paragraphs: [
          BookParagraph(
            text: 'Anna and Ben met at the park gate. The sky was blue and the sun was warm.',
          ),
          BookParagraph(
            text: '"Let us walk by the lake," said Anna. Ben nodded and smiled.',
          ),
        ],
      ),
      BookChapter(
        id: 'ch_park_2',
        title: 'The little duck',
        paragraphs: [
          BookParagraph(
            text: 'By the lake they saw a little duck with three baby ducks. The baby ducks swam in a line.',
          ),
          BookParagraph(
            text: 'Anna took a piece of bread from her bag and gave it to the ducks.',
          ),
          BookParagraph(
            text: '"That was kind," said Ben. "Let us come back tomorrow." And they did.',
          ),
        ],
      ),
    ],
  );
}
