/// UI language flags for the two built-in interfaces.
///
/// The app ships a Persian and an English interface natively; every other
/// native language is rendered through the live Google UI translation layer
/// (see [UiTranslationController]), driven by the ISO code in
/// [LanguageSettings.uiLanguageCode].
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
/// * the interface language and text direction derive from [nativeLanguage]:
///   the built-in Persian interface flips the UI to RTL, and every other
///   native language gets a live-translated interface via Google Translate;
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

  /// ISO code the UI should be rendered in: the learner's native language.
  /// English and Persian use the built-in interfaces; any other code drives
  /// the live Google UI translation layer.
  String get uiLanguageCode => nativeLanguage;

  /// Preferred translation/explanation language: the learner reads meanings
  /// in their native language.
  AppLanguage get translationLanguage => AppLanguage.fromCode(nativeLanguage);

  /// ISO code learning content is translated into: the learner's first/native
  /// language (the language picked during onboarding / settings). Content is
  /// authored in English and is live-translated into this language on demand.
  String get contentLanguageCode => nativeLanguage;

  /// Whether the UI should render right-to-left (Persian or Arabic native
  /// language).
  bool get isRtlUi {
    final code = nativeLanguage;
    return code == 'fa' || code == 'ar';
  }

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
