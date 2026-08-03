import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/env_config.dart';
import 'core/state/app_controller.dart';
import 'core/state/content_translation_controller.dart';
import 'core/state/language_controller.dart';
import 'core/state/ui_translation_controller.dart';
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
    return ContentLanguageSync(
      child: UiLanguageSync(
        child: MaterialApp(
          title: EnvConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: ZovaTheme.dark,
          locale: Locale(language.settings.uiLanguageCode),
          builder: (context, child) => Directionality(
            textDirection:
                language.isRtlUi ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SessionGate(),
        ),
      ),
    );
  }
}

/// Keeps the [UiTranslationController] target in sync with the chosen native
/// language so the whole interface re-translates live.
class UiLanguageSync extends StatefulWidget {
  const UiLanguageSync({super.key, required this.child});

  final Widget child;

  @override
  State<UiLanguageSync> createState() => _UiLanguageSyncState();
}

class _UiLanguageSyncState extends State<UiLanguageSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant UiLanguageSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final language = context.watch<LanguageController>();
    final ui = context.read<UiTranslationController?>();
    if (ui == null) return;
    final code = language.settings.uiLanguageCode;
    if (ui.code != code) ui.setCode(code);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Keeps the [ContentTranslationController] target in sync with the chosen
/// learning language so learning content re-translates live.
class ContentLanguageSync extends StatefulWidget {
  const ContentLanguageSync({super.key, required this.child});

  final Widget child;

  @override
  State<ContentLanguageSync> createState() => _ContentLanguageSyncState();
}

class _ContentLanguageSyncState extends State<ContentLanguageSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ContentLanguageSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final language = context.watch<LanguageController>();
    final content = context.read<ContentTranslationController?>();
    if (content == null) return;
    final code = language.settings.contentLanguageCode;
    if (content.code != code) content.setCode(code);
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
            final language = context.read<LanguageController>();
            controller.setOnboardingPrefs(prefs);
            await language.setLanguagePair(
              native: prefs.nativeLanguageCode,
              learning: prefs.learningLanguageCode,
            );
            await controller.markOnboarded();
          },
        ),
      (true, false) => const AuthGate(),
      (true, true) => const HomeShell(),
    };
  }
}
