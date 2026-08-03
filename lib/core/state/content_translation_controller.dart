import 'live_translation_controller.dart';

/// Live Google translation of learning content into the native (first)
/// language.
///
/// Vocabulary words, dictionary results, book sentences and grammar examples
/// are originally authored in English. This controller translates that content
/// into the learner's native language (the language picked in onboarding /
/// settings). The app UI is translated into the same language by
/// [UiTranslationController], while the second language (the one being learned)
/// drives dictionary lookups.
///
/// Screens can call [tr] while building; [ContentText] uses this controller.
class ContentTranslationController extends LiveTranslationController {
  ContentTranslationController({super.code, super.translator})
      : super(boxName: _boxName);

  static const String _boxName = 'content_translations';
}
