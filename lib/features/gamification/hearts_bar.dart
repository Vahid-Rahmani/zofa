import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/gamification_state.dart';

/// A compact hearts indicator bound to [AppController.hearts].
///
/// Shows the current hearts (filled/empty) and, when below maximum, the time
/// until the next heart refills (one per 30 minutes).
class HeartsBar extends StatelessWidget {
  const HeartsBar({super.key, this.showCount = false});

  /// Whether to show the numeric count next to the hearts.
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final hearts = controller.hearts;
    final full = hearts >= GamificationState.maxHearts;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < GamificationState.maxHearts; i++)
          Icon(
            i < hearts ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: i < hearts
                ? ZovaColors.error
                : ZovaColors.textSecondary.withValues(alpha: 0.4),
          ),
        if (showCount) ...[
          const SizedBox(width: 6),
          Text(
            '$hearts/${GamificationState.maxHearts}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textSecondary,
            ),
          ),
        ],
        if (!full) ...[
          const SizedBox(width: 8),
          Text(
            'refills in ${_refillHint(controller)}',
            style: const TextStyle(
              fontSize: 11,
              color: ZovaColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  String _refillHint(AppController controller) {
    final gamification = controller.gamification;
    final updatedAt = gamification.heartsUpdatedAt;
    if (updatedAt == null) return '30m';
    final elapsed =
        DateTime.now().difference(updatedAt).inMinutes.remainder(
              GamificationState.heartRegenInterval.inMinutes,
            );
    final minutes = (GamificationState.heartRegenInterval.inMinutes - elapsed)
        .clamp(1, GamificationState.heartRegenInterval.inMinutes);
    return '${minutes}m';
  }
}
