import 'package:flutter/foundation.dart';

import '../../data/models/language_settings.dart';
import '../../data/services/local_store.dart';

/// Owns the app's language preferences: the learner's native language and the
/// language being learned. Both are persisted on-device and exposed to the
/// widget tree via [ChangeNotifierProvider] so the UI language, directionality
/// and rendered explanations react immediately.
///
/// The interface language and RTL/LTR direction are derived from the native
/// language; changing it here flips the whole app.
class LanguageController extends ChangeNotifier {
  LanguageController({LanguageSettings? initial})
      : _settings = initial ?? const LanguageSettings();

  LanguageSettings _settings;

  LanguageSettings get settings => _settings;

  /// Whether the UI should render right-to-left (Persian native language).
  bool get isRtlUi => _settings.isRtlUi;

  /// Loads persisted preferences from the device. Safe to call at boot.
  Future<void> bootstrap() async {
    _settings = await LocalStore.getLanguageSettings();
    notifyListeners();
  }

  /// Sets the native (interface/explanation) language and persists it.
  Future<void> setNativeLanguage(String code) async {
    await _update(_settings.copyWith(nativeLanguage: code));
  }

  /// Sets the language being learned and persists it.
  Future<void> setLearningLanguage(String code) async {
    await _update(_settings.copyWith(learningLanguage: code));
  }

  /// Sets both sides of the language pair at once (used by onboarding).
  Future<void> setLanguagePair({
    required String native,
    required String learning,
  }) async {
    await _update(
      LanguageSettings(nativeLanguage: native, learningLanguage: learning),
    );
  }

  Future<void> _update(LanguageSettings next) async {
    _settings = next;
    notifyListeners();
    await LocalStore.saveLanguageSettings(next);
  }
}
