import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/app_user.dart';
import '../../data/models/translation_language.dart';
import '../../data/models/user_progress.dart';
import '../../data/services/gamification_catalog.dart';
import '../gamification/badges_screen.dart';
import '../gamification/league_screen.dart';
import '../settings/language_settings_screen.dart';
import '../subscription/paywall_screen.dart';

/// Profile tab: identity, stats, premium status and settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final user = controller.user;
    final progress = controller.progress;
    final language = context.watch<LanguageController>().settings;
    final nativeName =
        TranslationLanguage.byCode(language.nativeLanguage)?.name ??
            language.nativeLanguage;
    final learningName =
        TranslationLanguage.byCode(language.learningLanguage)?.name ??
            language.learningLanguage;
    final lessonsCompleted =
        progress.completedLessonsFor(language.learningLanguage).length;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: ZovaColors.surfaceRaised,
                  child: Text(user.avatarEmoji, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? user.email,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: ZovaColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$nativeName → $learningName',
                        style: const TextStyle(color: ZovaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _StatsGrid(progress: progress, lessonsCompleted: lessonsCompleted),
            const SizedBox(height: 24),
            _LeagueCard(
              tier: controller.league.tier,
              position: controller.league.playerPosition,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LeagueScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _BadgesCard(
              earnedCount: controller.gamification.earnedBadges.length,
              totalCount: GamificationCatalog.badges.length,
              earnedIcons: GamificationCatalog.badges
                  .where((b) => controller.gamification.earnedBadges.contains(b.id))
                  .map((b) => b.icon)
                  .toList(),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BadgesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _PremiumCard(
              active: progress.subscriptionActive,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PaywallScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              user: user,
              onAvatarChanged: (emoji) =>
                  controller.updateProfile(user.copyWith(avatarEmoji: emoji)),
              onLogout: controller.signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.progress, required this.lessonsCompleted});

  final UserProgress progress;
  final int lessonsCompleted;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('XP', '${progress.xp}', Icons.bolt, ZovaColors.primary),
      ('Streak', '${progress.streakDays}', Icons.local_fire_department, ZovaColors.warning),
      ('Words', '${progress.wordsLearned}', Icons.style, ZovaColors.secondary),
      ('Lessons', '$lessonsCompleted', Icons.school, ZovaColors.success),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        for (final (label, value, icon, color) in stats)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ZovaColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: ZovaColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({
    required this.tier,
    required this.position,
    required this.onTap,
  });

  final String tier;
  final int position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZovaColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: ZovaColors.warning, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$tier league',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You are #$position this week',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ZovaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: ZovaColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({
    required this.earnedCount,
    required this.totalCount,
    required this.earnedIcons,
    required this.onTap,
  });

  final int earnedCount;
  final int totalCount;
  final List<String> earnedIcons;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZovaColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.military_tech,
                  color: ZovaColors.warning, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$earnedCount of $totalCount badges',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final icon in earnedIcons.take(5))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(icon,
                                style: const TextStyle(fontSize: 18)),
                          ),
                        if (earnedIcons.isEmpty)
                          const Text(
                            'Complete lessons, build streaks and grow your '
                            'vocabulary to earn badges.',
                            style: TextStyle(
                              fontSize: 12,
                              color: ZovaColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: ZovaColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: active
              ? const [ZovaColors.success, Color(0xFF2F9E62)]
              : const [ZovaColors.gradientStart, ZovaColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.verified : Icons.workspace_premium,
              color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              active
                  ? 'zova Premium active'
                  : 'Unlock every lesson and book',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!active)
            TextButton(
              onPressed: onTap,
              child: const Text(
                'See plans',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.user,
    required this.onAvatarChanged,
    required this.onLogout,
  });

  final AppUser user;
  final ValueChanged<String> onAvatarChanged;
  final VoidCallback onLogout;

  static const _emojis = ['🚀', '🦊', '🐼', '🦁', '🐸', '🦄', '🐙', '🌟'];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZovaColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.face, color: ZovaColors.primary),
            title: const Text('Avatar'),
            trailing: Text(
              user.avatarEmoji,
              style: const TextStyle(fontSize: 22),
            ),
            onTap: () => _pickAvatar(context),
          ),
          const Divider(color: ZovaColors.surfaceRaised, height: 1),
          ListTile(
            leading: const Icon(Icons.language, color: ZovaColors.primary),
            title: const Text('Language'),
            subtitle: const Text('Interface & translations'),
            trailing: const Icon(Icons.chevron_right,
                color: ZovaColors.textSecondary),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LanguageSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(color: ZovaColors.surfaceRaised, height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: ZovaColors.error),
            title: const Text('Sign out', style: TextStyle(color: ZovaColors.error)),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ZovaColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick an avatar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final emoji in _emojis)
                  InkWell(
                    onTap: () => Navigator.pop(context, emoji),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ZovaColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) onAvatarChanged(choice);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your progress is saved on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) onLogout();
  }
}
