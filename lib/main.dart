import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/state/app_controller.dart';
import 'core/state/content_translation_controller.dart';
import 'core/state/language_controller.dart';
import 'core/state/ui_translation_controller.dart';
import 'data/services/remote_api.dart';
import 'data/services/stripe_service.dart';
import 'data/services/translation_backend.dart';
import 'data/services/translation_cache.dart';
import 'data/services/translation_service.dart';

/// Entry point. Boots the backend (Supabase when configured, otherwise the
/// local demo store) and hands control to the widget tree.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RemoteApi.instance.init();
  await StripeService.instance.init();

  // Boot the dynamic translation bridge: a Hive-persisted LRU cache layered
  // over the online lookup provider. Falls back to a memory-only cache when
  // the filesystem/Hive is unavailable.
  TranslationService.instance = TranslationService(
    backend: buildDefaultTranslationBackend(),
    cache: await _buildTranslationCache(),
  );

  final language = LanguageController();
  await language.bootstrap();

  // Live Google UI translation: the whole interface is translated into the
  // learner's native language and cached on-device.
  final uiTranslation = UiTranslationController();
  await uiTranslation.bootstrap();
  uiTranslation.setCode(language.settings.uiLanguageCode);

  // Live Google content translation: vocabulary, books and grammar are
  // translated into the learner's "second language" (the language being
  // learned) and cached on-device.
  final contentTranslation = ContentTranslationController();
  await contentTranslation.bootstrap();
  contentTranslation.setCode(language.settings.contentLanguageCode);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppController(language: language)),
        ChangeNotifierProvider.value(value: language),
        ChangeNotifierProvider.value(value: uiTranslation),
        ChangeNotifierProvider.value(value: contentTranslation),
      ],
      child: const ZovaApp(),
    ),
  );
}

Future<TranslationCache> _buildTranslationCache() async {
  try {
    final directory = await getApplicationSupportDirectory();
    Hive.init(directory.path);
    final cache = HiveTranslationCache();
    await cache.open();
    return cache;
  } catch (_) {
    return MemoryTranslationCache();
  }
}
