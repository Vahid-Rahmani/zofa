import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/models/translation_language.dart';

/// One full-screen page inside the onboarding flow.
class OnboardingPage {
  const OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;
}

/// Collects the language pair (native + learning) before the first lesson.
///
/// The chosen pair is persisted through [LanguageController] and drives the
/// app's interface language, text direction and dictionary defaults.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final ValueChanged<OnboardingPrefs> onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static final TranslationLanguage _defaultNative =
      TranslationLanguage.byCode('fa')!;
  static final TranslationLanguage _defaultLearning =
      kTranslationLanguages.firstWhere((l) => l != _defaultNative);

  TranslationLanguage _native = _defaultNative;
  TranslationLanguage _learning = _defaultLearning;

  static const _pages = [
    OnboardingPage(
      emoji: '🌍',
      title: 'What’s your native language?',
      subtitle:
          'The language you already speak. zova uses it for the interface '
          'and for word explanations.',
    ),
    OnboardingPage(
      emoji: '🎯',
      title: 'What do you want to learn?',
      subtitle:
          'Pick the language you want to master next. You can change it '
          'anytime in Settings.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _LanguagePickerPage(
                      page: _pages[0],
                      languages: kTranslationLanguages,
                      selected: _native,
                      onSelected: _selectNative,
                    );
                  }
                  return _LanguagePickerPage(
                    page: _pages[1],
                    languages: [
                      for (final language in kTranslationLanguages)
                        if (language != _native) language,
                    ],
                    selected: _learning,
                    onSelected: (language) =>
                        setState(() => _learning = language),
                  );
                },
              ),
            ),
            _BottomBar(
              index: _page,
              total: _pages.length,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  void _selectNative(TranslationLanguage language) {
    setState(() {
      _native = language;
      if (_learning == language) {
        _learning = kTranslationLanguages.firstWhere((l) => l != language);
      }
    });
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } else {
      widget.onFinished(
        OnboardingPrefs(
          nativeLanguageCode: _native.code,
          learningLanguageCode: _learning.code,
        ),
      );
    }
  }
}

class _LanguagePickerPage extends StatelessWidget {
  const _LanguagePickerPage({
    required this.page,
    required this.languages,
    required this.selected,
    required this.onSelected,
  });

  final OnboardingPage page;
  final List<TranslationLanguage> languages;
  final TranslationLanguage selected;
  final ValueChanged<TranslationLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text(page.emoji, style: const TextStyle(fontSize: 72))),
          const SizedBox(height: 24),
          TrText(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ZovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TrText(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: ZovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final language in languages)
                _LanguageChip(
                  language: language,
                  selected: language == selected,
                  onTap: () => onSelected(language),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final TranslationLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ZovaColors.primary : ZovaColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? ZovaColors.primary
                  : ZovaColors.textSecondary.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.nativeName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : ZovaColors.textPrimary,
                ),
              ),
              if (language.nativeName != language.name) ...[
                const SizedBox(height: 2),
                Text(
                  language.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : ZovaColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.total,
    required this.onNext,
  });

  final int index;
  final int total;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = index >= total - 1;
    context.watch<UiTranslationController?>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              total,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index
                      ? ZovaColors.primary
                      : ZovaColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: context.tr(isLast ? 'Start learning' : 'Continue'),
            icon: isLast ? null : Icons.arrow_forward,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
