import 'ai_word_details.dart';

/// A grammar rule explained by the AI tutor for the learner's active session.
///
/// Carries a short [summary], a fuller [explanation] written in the learner's
/// native language, contextual [examples] with glosses and an optional [tip].
/// Cached locally so repeat questions are instant and the app stays usable
/// under rate limits or offline.
class AiGrammarExplanation {
  const AiGrammarExplanation({
    required this.topic,
    this.summary,
    this.explanation,
    this.examples = const [],
    this.tip,
    this.fromCache = false,
    this.cachedAt,
  });

  /// The topic or question the learner asked about.
  final String topic;

  /// One-line takeaway, written in the learner's native language.
  final String? summary;

  /// The full explanation.
  final String? explanation;

  /// Contextual example sentences, each with its own gloss.
  final List<AiExample> examples;

  /// A learner-friendly memory aid, when the model provides one.
  final String? tip;

  /// True when served from the local cache rather than the model.
  final bool fromCache;

  /// When the result was cached, if known.
  final DateTime? cachedAt;

  /// True when the response carried nothing usable.
  bool get isEmpty =>
      (summary?.trim().isEmpty ?? true) &&
      (explanation?.trim().isEmpty ?? true);

  /// True when the response carried at least one useful field.
  bool get hasAnything =>
      summary != null ||
      explanation != null ||
      examples.isNotEmpty ||
      tip != null;

  AiGrammarExplanation copyWith({bool? fromCache, DateTime? cachedAt}) {
    return AiGrammarExplanation(
      topic: topic,
      summary: summary,
      explanation: explanation,
      examples: examples,
      tip: tip,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation (used by the persistent AI cache)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'summary': summary,
        'explanation': explanation,
        'examples': [for (final e in examples) e.toJson()],
        'tip': tip,
        'from_cache': fromCache,
        'cached_at': cachedAt?.toIso8601String(),
      };

  factory AiGrammarExplanation.fromJson(Map<String, dynamic> json) {
    final cachedAtRaw = json['cached_at'] as String?;
    return AiGrammarExplanation(
      topic: json['topic'] as String,
      summary: json['summary'] as String?,
      explanation: json['explanation'] as String?,
      examples: [
        for (final e in (json['examples'] as List<dynamic>? ?? const []))
          AiExample.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      tip: json['tip'] as String?,
      fromCache: json['from_cache'] as bool? ?? false,
      cachedAt: cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw),
    );
  }
}
