import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/state/app_controller.dart';
import 'core/state/language_controller.dart';
import 'data/services/remote_api.dart';
import 'data/services/stripe_service.dart';

/// Entry point. Boots the backend (Supabase when configured, otherwise the
/// local demo store) and hands control to the widget tree.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RemoteApi.instance.init();
  await StripeService.instance.init();

  final language = LanguageController();
  await language.bootstrap();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppController(language: language)),
        ChangeNotifierProvider.value(value: language),
      ],
      child: const ZovaApp(),
    ),
  );
}
