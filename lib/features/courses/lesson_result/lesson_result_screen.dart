import 'package:flutter/material.dart';

import '../../../core/theme/zova_colors.dart';
import '../../../core/widgets/gradient_button.dart';

/// Celebratory screen shown after a lesson finishes.
class LessonResultScreen extends StatelessWidget {
  const LessonResultScreen({
    super.key,
    required this.lessonTitle,
    required this.correct,
    required this.total,
    required this.xp,
    required this.words,
    this.boosted = false,
  });

  final String lessonTitle;
  final int correct;
  final int total;
  final int xp;
  final int words;
  final bool boosted;

  int get _stars => total == 0
      ? 0
      : correct == total
          ? 3
          : correct >= (total / 2).ceil()
              ? 2
              : 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(lessonTitle,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: ZovaColors.textPrimary)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => Icon(
                    index < _stars ? Icons.star : Icons.star_border,
                    size: 44,
                    color: index < _stars
                        ? ZovaColors.gold
                        : ZovaColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (boosted) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: ZovaColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: ZovaColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Double XP boost active!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ZovaColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _RewardRow(
                icon: Icons.bolt,
                label: 'Experience',
                value: '+$xp XP',
                color: ZovaColors.primary,
              ),
              const SizedBox(height: 14),
              _RewardRow(
                icon: Icons.style,
                label: 'New words',
                value: '$words',
                color: ZovaColors.secondary,
              ),
              const SizedBox(height: 14),
              const _RewardRow(
                icon: Icons.local_fire_department,
                label: 'Streak',
                value: '1 day',
                color: ZovaColors.warning,
              ),
              const Spacer(flex: 3),
              GradientButton(
                label: 'Continue',
                icon: Icons.arrow_forward,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ZovaColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ZovaColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
