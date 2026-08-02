import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/env_config.dart';
import 'core/state/app_controller.dart';
import 'core/state/language_controller.dart';
import 'core/theme/zova_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';

/// Root widget of the zova app.
class ZovaApp extends StatelessWidget {
  const ZovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageController>();
    return MaterialApp(
      title: EnvConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ZovaTheme.dark,
      locale: Locale(language.settings.uiLanguage.code),
      builder: (context, child) => Directionality(
        textDirection:
            language.isRtlUi ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SessionGate(),
    );
  }
}

/// Routes the user through splash -> onboarding -> auth -> home.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<AppController>();
      await controller.bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    if (!controller.booted) return const SplashScreen();

    return switch ((controller.isOnboarded, controller.isSignedIn)) {
      (false, _) => OnboardingScreen(
          onFinished: (prefs) async {
            final controller = context.read<AppController>();
            controller.setOnboardingPrefs(prefs);
            await controller.markOnboarded();
          },
        ),
      (true, false) => const AuthGate(),
      (true, true) => const HomeShell(),
    };
  }
}
