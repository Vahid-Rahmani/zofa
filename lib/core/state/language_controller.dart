import 'package:flutter/foundation.dart';

import '../../data/models/language_settings.dart';
import '../../data/services/local_store.dart';

/// Owns the app's language preferences: the UI language and the preferred
/// translation/explanation language. Both are persisted on-device and exposed
/// to the widget tree via [ChangeNotifierProvider] so the UI language,
/// directionality and rendered explanations react immediately.
class LanguageController extends ChangeNotifier {
  LanguageController({LanguageSettings? initial})
      : _settings = initial ?? const LanguageSettings();

  LanguageSettings _settings;

  LanguageSettings get settings => _settings;

  /// Whether the UI should render right-to-left (Persian).
  bool get isRtlUi => _settings.isRtlUi;

  /// Loads persisted preferences from the device. Safe to call at boot.
  Future<void> bootstrap() async {
    _settings = await LocalStore.getLanguageSettings();
    notifyListeners();
  }

  /// Sets the interface language and persists the choice.
  Future<void> setUiLanguage(AppLanguage language) async {
    await _update(_settings.copyWith(uiLanguage: language));
  }

  /// Sets the preferred translation/explanation language and persists it.
  Future<void> setTranslationLanguage(AppLanguage language) async {
    await _update(_settings.copyWith(translationLanguage: language));
  }

  Future<void> _update(LanguageSettings next) async {
    _settings = next;
    notifyListeners();
    await LocalStore.saveLanguageSettings(next);
  }
}
