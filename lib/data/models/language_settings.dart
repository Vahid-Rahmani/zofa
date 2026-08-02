/// Languages the app's UI and explanations can be switched to.
///
/// The app teaches via a 3-way bridge (target language <-> English <->
/// Persian). These two languages cover both sides of the explanation bridge:
/// the UI/interface language and the preferred translation/explanation
/// language can each be set to English or Persian independently.
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

/// User language preferences: which language the interface is shown in and
/// which language dictionary translations/explanations are rendered in.
class LanguageSettings {
  const LanguageSettings({
    this.uiLanguage = AppLanguage.english,
    this.translationLanguage = AppLanguage.persian,
  });

  /// Interface / app language.
  final AppLanguage uiLanguage;

  /// Preferred translation & explanation language (the "base explanation
  /// language" the learner reads meanings in).
  final AppLanguage translationLanguage;

  /// Whether the UI should render right-to-left (Persian).
  bool get isRtlUi => uiLanguage == AppLanguage.persian;

  LanguageSettings copyWith({
    AppLanguage? uiLanguage,
    AppLanguage? translationLanguage,
  }) {
    return LanguageSettings(
      uiLanguage: uiLanguage ?? this.uiLanguage,
      translationLanguage: translationLanguage ?? this.translationLanguage,
    );
  }

  factory LanguageSettings.fromJson(Map<String, dynamic> json) {
    return LanguageSettings(
      uiLanguage: AppLanguage.fromCode(json['ui_language'] as String?),
      translationLanguage:
          AppLanguage.fromCode(json['translation_language'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'ui_language': uiLanguage.code,
        'translation_language': translationLanguage.code,
      };
}
