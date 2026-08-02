import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/translation_language.dart';
import '../../data/services/translation_service.dart';

/// Lets the learner set their language pair: the native language (which also
/// drives the interface language, text direction and word explanations) and
/// the language they are learning.
///
/// Both choices are persisted by [LanguageController]; changing the native
/// language flips the app's locale and text direction immediately.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LanguageController>();
    final settings = controller.settings;
    final native = TranslationLanguage.byCode(settings.nativeLanguage);
    final learning = TranslationLanguage.byCode(settings.learningLanguage);

    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const Text(
              'Native language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The language you already speak. zova uses it for the '
              'interface, text direction and word explanations.',
              style: TextStyle(color: ZovaColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _LanguageGrid(
              languages: kTranslationLanguages,
              selected: native,
              onTap: (language) => _selectNative(controller, language),
            ),
            const SizedBox(height: 28),
            const Text(
              'Learning language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The language you are learning. Dictionary lookups default to '
              'translating between this and your native language.',
              style: TextStyle(color: ZovaColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _LanguageGrid(
              languages: [
                for (final language in kTranslationLanguages)
                  if (language != native) language,
              ],
              selected: learning,
              onTap: (language) => controller.setLearningLanguage(language.code),
            ),
            const SizedBox(height: 28),
            const Text(
              'Dictionary cache',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lookups are cached on-device so recently viewed words open '
              'instantly and work offline.',
              style: TextStyle(color: ZovaColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                ),
                onPressed: () async {
                  await TranslationService.instance.clearCache();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cached translations cleared'),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                label: const Text('Clear cached translations'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectNative(
    LanguageController controller,
    TranslationLanguage language,
  ) async {
    await controller.setNativeLanguage(language.code);
    // Keep the two sides distinct so the dictionary always has a real pair.
    if (controller.settings.learningLanguage == language.code) {
      final other = kTranslationLanguages.firstWhere((l) => l != language);
      await controller.setLearningLanguage(other.code);
    }
  }
}

class _LanguageGrid extends StatelessWidget {
  const _LanguageGrid({
    required this.languages,
    required this.selected,
    required this.onTap,
  });

  final List<TranslationLanguage> languages;
  final TranslationLanguage? selected;
  final ValueChanged<TranslationLanguage> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final language in languages)
          _LanguageChip(
            language: language,
            selected: language == selected,
            onTap: () => onTap(language),
          ),
      ],
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
