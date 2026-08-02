import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/language_settings.dart';
import '../../data/services/translation_service.dart';

/// Lets the learner set, independently, the interface language and the
/// preferred translation/explanation language (both English or Persian).
///
/// Both choices are persisted by [LanguageController]; the interface language
/// also flips the app's locale and text direction immediately.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LanguageController>();
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const Text(
              'Interface language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The language of buttons, labels and navigation.',
              style: TextStyle(color: ZovaColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _LanguageTile(
              label: AppLanguage.english.label,
              code: AppLanguage.english.code,
              selected: settings.uiLanguage == AppLanguage.english,
              onTap: () => controller.setUiLanguage(AppLanguage.english),
            ),
            const SizedBox(height: 10),
            _LanguageTile(
              label: AppLanguage.persian.label,
              code: AppLanguage.persian.code,
              selected: settings.uiLanguage == AppLanguage.persian,
              onTap: () => controller.setUiLanguage(AppLanguage.persian),
            ),
            const SizedBox(height: 28),
            const Text(
              'Translations & explanations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The language word meanings, definitions and examples are '
              'shown in across the dictionary and reviews.',
              style: TextStyle(color: ZovaColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _LanguageTile(
              label: AppLanguage.persian.label,
              code: AppLanguage.persian.code,
              selected: settings.translationLanguage == AppLanguage.persian,
              onTap: () => controller.setTranslationLanguage(AppLanguage.persian),
            ),
            const SizedBox(height: 10),
            _LanguageTile(
              label: AppLanguage.english.label,
              code: AppLanguage.english.code,
              selected: settings.translationLanguage == AppLanguage.english,
              onTap: () => controller.setTranslationLanguage(AppLanguage.english),
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
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZovaColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ZovaColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 12,
                  color: ZovaColors.textSecondary,
                ),
              ),
              const Spacer(),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? ZovaColors.primary : ZovaColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
