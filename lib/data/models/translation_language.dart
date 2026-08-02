/// A language that can act as either the source or the target of a dynamic
/// translation lookup.
///
/// Unlike the bundled dictionaries (which ship English and German only), the
/// dynamic translation bridge supports **any** pair of languages: German to
/// Persian, German to Hindi, English to Spanish, and so on. [code] is the
/// ISO 639-1 code used by the translation provider; [isRtl] tells the UI which
/// text direction to render the results in.
class TranslationLanguage {
  const TranslationLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    this.isRtl = false,
  });

  /// ISO 639-1 code, e.g. `en`, `de`, `fa`, `hi`, `es`.
  final String code;

  /// English name of the language.
  final String name;

  /// Name written in the language itself (e.g. فارسی for Persian).
  final String nativeName;

  /// Whether the language is written right-to-left (e.g. Persian, Arabic).
  final bool isRtl;

  /// Short display label: the native name when available, otherwise the
  /// English name.
  String get label => nativeName.isEmpty ? name : nativeName;

  @override
  bool operator ==(Object other) => other is TranslationLanguage && other.code == code;

  @override
  int get hashCode => code.hashCode;

  /// Looks up a language by its ISO code, or `null` when it is unknown.
  static TranslationLanguage? byCode(String? code) {
    if (code == null) return null;
    for (final language in kTranslationLanguages) {
      if (language.code == code) return language;
    }
    return null;
  }
}

/// The built-in catalogue of languages offered by the dynamic translation
/// bridge. Any of these can be the source or the target of a lookup, and the
/// provider handles pairs not listed here too.
const List<TranslationLanguage> kTranslationLanguages = [
  TranslationLanguage(code: 'en', name: 'English', nativeName: 'English'),
  TranslationLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
  TranslationLanguage(code: 'fa', name: 'Persian', nativeName: 'فارسی', isRtl: true),
  TranslationLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
  TranslationLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
  TranslationLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
  TranslationLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
  TranslationLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  TranslationLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية', isRtl: true),
  TranslationLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
  TranslationLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский'),
  TranslationLanguage(code: 'zh', name: 'Chinese', nativeName: '中文'),
  TranslationLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
  TranslationLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
];
