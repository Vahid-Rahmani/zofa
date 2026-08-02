/// A paragraph of text inside a book chapter.
class BookParagraph {
  const BookParagraph({required this.text});

  final String text;

  factory BookParagraph.fromJson(Map<String, dynamic> json) {
    return BookParagraph(text: json['text'] as String);
  }

  Map<String, dynamic> toJson() => {'text': text};
}

/// A chapter is a sequence of paragraphs; the reader tracks progress in it.
class BookChapter {
  const BookChapter({
    required this.id,
    required this.title,
    required this.paragraphs,
  });

  final String id;
  final String title;
  final List<BookParagraph> paragraphs;

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      id: json['id'] as String,
      title: json['title'] as String,
      paragraphs: (json['paragraphs'] as List<dynamic>)
          .map((e) => BookParagraph.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'paragraphs': paragraphs.map((e) => e.toJson()).toList(),
      };
}

/// An interactive book: the second pillar of the learning experience.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.cover,
    required this.difficulty,
    required this.chapters,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String cover;
  final String difficulty;
  final List<BookChapter> chapters;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      description: json['description'] as String,
      cover: (json['cover'] as String?) ?? '📘',
      difficulty: (json['difficulty'] as String?) ?? 'Beginner',
      chapters: (json['chapters'] as List<dynamic>)
          .map((e) => BookChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'description': description,
        'cover': cover,
        'difficulty': difficulty,
        'chapters': chapters.map((e) => e.toJson()).toList(),
      };
}
