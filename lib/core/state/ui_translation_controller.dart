import 'live_translation_controller.dart';

/// Live Google translation of the app's UI.
///
/// Every hard-coded English UI string is translated on demand into the
/// learner's chosen native language (the "first language" picked in
/// onboarding / settings). [TrText] and `context.tr` use this controller.
class UiTranslationController extends LiveTranslationController {
  UiTranslationController({super.code, super.translator})
      : super(boxName: _boxName);

  static const String _boxName = 'ui_translations';
}
