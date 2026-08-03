import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/gamification_state.dart';
import '../../data/services/gamification_catalog.dart';

/// Weekly league leaderboard with the learner's tier, their rank against the
/// week's simulated competitors, plus a power-ups panel for the XP boost,
/// streak freeze and the daily free gift.
class LeagueScreen extends StatelessWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final league = controller.league;
    final gamification = controller.gamification;
    final boostCount =
        gamification.ownedItems[GamificationState.itemXpBoost] ?? 0;
    final freezeCount =
        gamification.ownedItems[GamificationState.itemStreakFreeze] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('League · ${league.tier}',
            style: const TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            _TierBanner(league: league),
            const SizedBox(height: 20),
            const Text(
              'This week',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _LeagueList(league: league),
            const SizedBox(height: 28),
            const Text(
              'Power-ups',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _DailyGiftCard(
              available: controller.dailyGiftAvailable,
              onClaim: () {
                controller.claimDailyGift();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Daily gift claimed! +1 XP boost, +1 freeze'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _PowerUpTile(
              icon: Icons.bolt,
              color: ZovaColors.primary,
              title: 'Double XP boost',
              subtitle: 'Doubles all XP earned for 15 minutes.',
              count: boostCount,
              active: controller.boostActive,
              actionLabel: controller.boostActive ? 'Active' : 'Activate',
              onPressed: controller.boostActive || boostCount == 0
                  ? null
                  : () {
                      controller.activateBoost();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('XP boost active for 15 minutes!'),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            _PowerUpTile(
              icon: Icons.ac_unit,
              color: ZovaColors.secondary,
              title: 'Streak freeze',
              subtitle: 'Keeps your streak when you miss a day.',
              count: freezeCount,
              active: false,
              actionLabel: freezeCount > 0 ? 'Owned' : 'None',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TierBanner extends StatelessWidget {
  const _TierBanner({required this.league});

  final LeagueTable league;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ZovaColors.gradientStart, ZovaColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${league.tier} league',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You are #${league.playerPosition} this week · '
                  '${league.playerXp} XP',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueList extends StatelessWidget {
  const _LeagueList({required this.league});

  final LeagueTable league;

  @override
  Widget build(BuildContext context) {
    final top = league.entries.length < 3 ? league.entries.length : 3;
    final podium = league.entries.sublist(0, top);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PodiumPlace(
              name: podium.length > 1 ? podium[1].name : '—',
              xp: podium.length > 1 ? podium[1].xp : 0,
              color: ZovaColors.textSecondary,
              height: 64,
            ),
            const SizedBox(width: 10),
            _PodiumPlace(
              name: podium.isNotEmpty ? podium[0].name : '—',
              xp: podium.isNotEmpty ? podium[0].xp : 0,
              color: ZovaColors.warning,
              height: 84,
            ),
            const SizedBox(width: 10),
            _PodiumPlace(
              name: podium.length > 2 ? podium[2].name : '—',
              xp: podium.length > 2 ? podium[2].xp : 0,
              color: const Color(0xFFC2762B),
              height: 52,
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final (i, entry) in league.entries.indexed) ...[
          _LeaderRow(
            rank: i + 1,
            name: entry.name,
            xp: entry.xp,
            isPlayer: entry.isPlayer,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.name,
    required this.xp,
    required this.color,
    required this.height,
  });

  final String name;
  final int xp;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ZovaColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ZovaColors.textPrimary,
                ),
              ),
              Text('$xp XP',
                  style: const TextStyle(
                      fontSize: 11, color: ZovaColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 44,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.xp,
    required this.isPlayer,
  });

  final int rank;
  final String name;
  final int xp;
  final bool isPlayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isPlayer
            ? ZovaColors.primary.withValues(alpha: 0.12)
            : ZovaColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isPlayer ? FontWeight.w800 : FontWeight.w600,
                color: ZovaColors.textPrimary,
              ),
            ),
          ),
          if (isPlayer) ...[
            const Icon(Icons.star, color: ZovaColors.warning, size: 16),
            const SizedBox(width: 4),
          ],
          Text(
            '$xp XP',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ZovaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyGiftCard extends StatelessWidget {
  const _DailyGiftCard({required this.available, required this.onClaim});

  final bool available;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZovaColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily gift',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                Text(
                  'One XP boost + one streak freeze, free.',
                  style: TextStyle(
                      fontSize: 12, color: ZovaColors.textSecondary),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ZovaColors.warning),
            onPressed: available ? onClaim : null,
            child: Text(available ? 'Claim' : 'Claimed'),
          ),
        ],
      ),
    );
  }
}

class _PowerUpTile extends StatelessWidget {
  const _PowerUpTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.active,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int count;
  final bool active;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '×$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: ZovaColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: active ? color : ZovaColors.primary,
            ),
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
