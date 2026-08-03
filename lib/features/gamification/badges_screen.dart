import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../../data/services/gamification_catalog.dart' as catalog;

/// Achievements screen: the full badge catalog with earned slots highlighted
/// and locked ones dimmed.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final earned = controller.gamification.earnedBadges.toSet();
    context.watch<UiTranslationController?>();

    return Scaffold(
      appBar: AppBar(
        title: const TrText('Badges', style: TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text(
              context.trTempl('{0} of {1} badges earned', [
                earned.length,
                catalog.GamificationCatalog.badges.length,
              ]),
              style: const TextStyle(color: ZovaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                for (final badge in catalog.GamificationCatalog.badges)
                  _BadgeCard(badge: badge, unlocked: earned.contains(badge.id)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.unlocked});

  final catalog.Badge badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unlocked
              ? ZovaColors.surface
              : ZovaColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: unlocked
              ? Border.all(color: ZovaColors.warning.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              unlocked ? badge.icon : '🔒',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: ZovaColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
