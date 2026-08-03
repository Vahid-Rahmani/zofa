import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/services/gamification_catalog.dart';

/// Daily quests screen: the three Duolingo-style daily goals with live
/// progress and one-tap claim buttons.
class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final gamification = controller.gamification;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Quests', style: TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const Text(
              'Complete goals today to earn bonus XP.',
              style: TextStyle(color: ZovaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final quest in GamificationCatalog.quests) ...[
              _QuestTile(
                quest: quest,
                progress: quest.progressOf(gamification),
                claimed:
                    gamification.claimedQuests.contains(quest.id),
                onClaim: () => controller.claimQuest(quest.id),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
              'Quests reset every day at midnight.',
              style: TextStyle(
                fontSize: 12,
                color: ZovaColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.quest,
    required this.progress,
    required this.claimed,
    required this.onClaim,
  });

  final DailyQuest quest;
  final int progress;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final complete = progress >= quest.target;
    final ratio = (progress / quest.target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: complete
                  ? ZovaColors.success.withValues(alpha: 0.15)
                  : ZovaColors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(quest.icon, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: complete
                        ? ZovaColors.success
                        : ZovaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: ZovaColors.surfaceRaised,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      complete
                          ? ZovaColors.success
                          : ZovaColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  claimed
                      ? 'Reward claimed ✓'
                      : '$progress / ${quest.target}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ZovaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          claimed
              ? const Icon(Icons.check_circle,
                  color: ZovaColors.success, size: 28)
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        complete ? ZovaColors.success : ZovaColors.surfaceRaised,
                    foregroundColor:
                        complete ? Colors.white : ZovaColors.textSecondary,
                    disabledBackgroundColor: ZovaColors.surfaceRaised,
                  ),
                  onPressed: complete ? onClaim : null,
                  child: Text('+${quest.xpReward} XP'),
                ),
        ],
      ),
    );
  }
}
