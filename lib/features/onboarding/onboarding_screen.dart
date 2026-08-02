import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/gradient_button.dart';

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

/// Collects the user's preferences before the first lesson.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final ValueChanged<OnboardingPrefs> onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  String _nativeLanguage = 'Persian';
  String _level = 'beginner';
  String _motivation = 'travel';

  static const _pages = [
    OnboardingPage(
      emoji: '🌍',
      title: 'Learn a language you love',
      subtitle:
          'zova turns everyday learning into a habit with lessons, stories and games.',
    ),
    OnboardingPage(
      emoji: '📖',
      title: 'Read real stories',
      subtitle:
          'Tap any word in a story to see its meaning. Your vocabulary grows as you read.',
    ),
    OnboardingPage(
      emoji: '🚀',
      title: 'Stay motivated',
      subtitle:
          'Daily streaks, experience points and a clear roadmap keep you moving forward.',
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
                itemCount: _pages.length + 1,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  if (index < _pages.length) {
                    return _IntroPage(page: _pages[index]);
                  }
                  return _PrefsPage(
                    nativeLanguage: _nativeLanguage,
                    level: _level,
                    motivation: _motivation,
                    onNativeChanged: (v) => setState(() => _nativeLanguage = v),
                    onLevelChanged: (v) => setState(() => _level = v),
                    onMotivationChanged: (v) => setState(() => _motivation = v),
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

  void _next() {
    if (_page < _pages.length) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } else {
      widget.onFinished(
        OnboardingPrefs(
          nativeLanguage: _nativeLanguage,
          level: _level,
          motivation: _motivation,
        ),
      );
    }
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(page.emoji, style: const TextStyle(fontSize: 96)),
          const SizedBox(height: 32),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ZovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: ZovaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefsPage extends StatelessWidget {
  const _PrefsPage({
    required this.nativeLanguage,
    required this.level,
    required this.motivation,
    required this.onNativeChanged,
    required this.onLevelChanged,
    required this.onMotivationChanged,
  });

  final String nativeLanguage;
  final String level;
  final String motivation;
  final ValueChanged<String> onNativeChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onMotivationChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A few questions',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ZovaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We will tailor your roadmap.',
            style: TextStyle(color: ZovaColors.textSecondary),
          ),
          const SizedBox(height: 32),
          _PrefsBlock(
            title: 'Your language',
            options: const [
              'Persian',
              'German',
              'French',
              'Spanish',
              'Portuguese',
            ],
            selected: nativeLanguage,
            onChanged: onNativeChanged,
          ),
          const SizedBox(height: 28),
          _PrefsBlock(
            title: 'Your level',
            options: const ['beginner', 'intermediate', 'advanced'],
            selected: level,
            onChanged: onLevelChanged,
          ),
          const SizedBox(height: 28),
          _PrefsBlock(
            title: 'Main goal',
            options: const ['travel', 'work', 'study', 'fun'],
            selected: motivation,
            onChanged: onMotivationChanged,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PrefsBlock extends StatelessWidget {
  const _PrefsBlock({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ZovaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = option == selected;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onChanged(option),
              selectedColor: ZovaColors.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : ZovaColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: ZovaColors.surface,
            );
          }).toList(),
        ),
      ],
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
    final isLast = index >= total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              total + 1,
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
            label: isLast ? 'Start learning' : 'Continue',
            icon: isLast ? null : Icons.arrow_forward,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
