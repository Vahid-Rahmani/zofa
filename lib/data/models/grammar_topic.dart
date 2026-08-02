/// A single grammar point with bilingual examples.
class GrammarTopic {
  const GrammarTopic({
    required this.id,
    required this.title,
    required this.faTitle,
    required this.level,
    required this.icon,
    required this.summary,
    required this.explanation,
    required this.examples,
    this.tip,
  });

  final String id;
  final String title;
  final String faTitle;

  /// CEFR level this topic is first taught at (A1, A2, B1).
  final String level;
  final String icon;
  final String summary;
  final String explanation;
  final List<GrammarExample> examples;
  final String? tip;
}

/// A bilingual example sentence for a [GrammarTopic].
class GrammarExample {
  const GrammarExample({required this.english, required this.persian});

  final String english;
  final String persian;
}
