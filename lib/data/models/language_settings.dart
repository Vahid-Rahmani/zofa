/// Languages the app's UI can be rendered in.
///
/// The app ships a Persian and an English interface. Every other native
/// language falls back to the English UI.
enum AppLanguage {
  english('en', 'English'),
  persian('fa', 'فارسی');

  const AppLanguage(this.code, this.label);

  /// ISO 639-1 code.
  final String code;

  /// Human-readable label in its own language.
  final String label;

  static AppLanguage fromCode(String? code) =>
      code == 'fa' ? AppLanguage.persian : AppLanguage.english;
}

/// User language preferences: the learner's native language and the language
/// they are learning. Both are ISO 639-1 codes and together define the
/// app-wide language behaviour:
///
/// * the interface language and text direction derive from [nativeLanguage]
///   (Persian flips the UI to RTL, everything else stays LTR English);
/// * dictionary/explanation defaults point at the native ↔ learning pair.
class LanguageSettings {
  const LanguageSettings({
    this.nativeLanguage = 'fa',
    this.learningLanguage = 'en',
  });

  /// ISO 639-1 code of the learner's native language (e.g. `fa`, `en`).
  final String nativeLanguage;

  /// ISO 639-1 code of the language being learned (e.g. `de`, `en`).
  final String learningLanguage;

  /// Interface language, derived from [nativeLanguage]: Persian when the
  /// native language is Persian, English otherwise.
  AppLanguage get uiLanguage => AppLanguage.fromCode(nativeLanguage);

  /// Preferred translation/explanation language: the learner reads meanings
  /// in their native language.
  AppLanguage get translationLanguage => AppLanguage.fromCode(nativeLanguage);

  /// Whether the UI should render right-to-left (Persian interface).
  bool get isRtlUi => uiLanguage == AppLanguage.persian;

  LanguageSettings copyWith({
    String? nativeLanguage,
    String? learningLanguage,
  }) {
    return LanguageSettings(
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      learningLanguage: learningLanguage ?? this.learningLanguage,
    );
  }

  factory LanguageSettings.fromJson(Map<String, dynamic> json) {
    final native = json['native_language'] as String?;
    final learning = json['learning_language'] as String?;
    if (native != null && learning != null) {
      return LanguageSettings(
        nativeLanguage: native,
        learningLanguage: learning,
      );
    }
    // Legacy schema: the old explanation language is the learner's native
    // language, and the old interface language is what they were learning.
    final ui = AppLanguage.fromCode(json['ui_language'] as String?);
    final explanation =
        AppLanguage.fromCode(json['translation_language'] as String?);
    return LanguageSettings(
      nativeLanguage:
          explanation == AppLanguage.persian ? 'fa' : 'en',
      learningLanguage: ui == AppLanguage.persian ? 'fa' : 'en',
    );
  }

  Map<String, dynamic> toJson() => {
        'native_language': nativeLanguage,
        'learning_language': learningLanguage,
      };
}
