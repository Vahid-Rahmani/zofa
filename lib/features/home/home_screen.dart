import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_controller.dart';
import '../../core/state/language_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../data/models/app_user.dart';
import '../../data/models/course.dart';
import '../../data/models/translation_language.dart';
import '../../data/services/seed_content.dart';
import '../alphabet/alphabet_screen.dart';
import '../books/books_screen.dart';
import '../gamification/badges_screen.dart';
import '../gamification/hearts_bar.dart';
import '../gamification/league_screen.dart';
import '../gamification/quests_screen.dart';
import '../grammar/grammar_screen.dart';
import '../leitner/leitner_screen.dart';
import '../mywords/my_words_screen.dart';
import '../subscription/paywall_screen.dart';

/// The Home tab: a modern learning dashboard.
///
/// Top row greets the learner with streak and XP, a "Continue learning" card
/// drives daily practice, the Learn grid opens the main study modes, and the
/// Quick access grid surfaces review tools, the shop and social links.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigateToTab});

  /// Switches the bottom navigation to the tab at [index].
  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final user = controller.user;
    if (user == null) return const SizedBox.shrink();

    final languageCode = context
        .watch<LanguageController>()
        .settings
        .learningLanguage;
    final languageName =
        TranslationLanguage.byCode(languageCode)?.name ?? languageCode;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            _GreetingHeader(
              user: user,
              learningLanguageName: languageName,
              streak: controller.progress.streakDays,
              xp: controller.progress.xp,
            ),
            const SizedBox(height: 20),
            _ContinueCard(onGoToCourses: () => onNavigateToTab(1)),
            const SizedBox(height: 20),
            _GamificationSection(
              onQuests: () => _push(context, const QuestsScreen()),
              onLeague: () => _push(context, const LeagueScreen()),
              onBadges: () => _push(context, const BadgesScreen()),
            ),
            const SizedBox(height: 28),
            const _SectionHeader(
              title: 'Learn',
              subtitle: 'Choose how you want to study today',
            ),
            const SizedBox(height: 14),
            _FeatureGrid(
              onVocabulary: () => onNavigateToTab(2),
              onListeningReading: () =>
                  _push(context, const BooksScreen()),
              onAlphabet: () => _push(context, const AlphabetScreen()),
              onGrammar: () => _push(context, const GrammarScreen()),
            ),
            const SizedBox(height: 28),
            const _SectionHeader(
              title: 'Quick access',
              subtitle: 'Review, shop and share',
            ),
            const SizedBox(height: 14),
            _QuickAccessGrid(
              onLeitner: () => _push(context, const LeitnerBoxScreen()),
              onMyWords: () => _push(context, const MyWordsScreen()),
              onShop: () => _push(context, const PaywallScreen()),
              onSocial: () => _showSocialSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _showSocialSheet(BuildContext context) {
    const socials = [
      ('Instagram', '@zova.learn', Icons.camera_alt_outlined),
      ('Telegram', '@zova_learn', Icons.send_outlined),
      ('YouTube', 'zova learn', Icons.play_circle_outline),
      ('X (Twitter)', '@zovalearn', Icons.alternate_email),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZovaColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Follow zova',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Learn tips and new words every day.',
              style: TextStyle(color: ZovaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final (name, handle, icon) in socials) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZovaColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: ZovaColors.primary, size: 22),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  handle,
                  style: const TextStyle(color: ZovaColors.textSecondary),
                ),
                trailing: const Icon(Icons.copy, color: ZovaColors.textSecondary),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: handle));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $handle to clipboard')),
                  );
                },
              ),
              if (name != socials.last.$1)
                const Divider(color: ZovaColors.surface, height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.user,
    required this.learningLanguageName,
    required this.streak,
    required this.xp,
  });

  final AppUser user;

  /// Name of the language currently being learned (driven by the active
  /// language pair, not by the profile snapshot).
  final String learningLanguageName;
  final int streak;
  final int xp;

  String get _firstName {
    final name = user.displayName ?? user.email;
    final first = name.split(RegExp(r'[ @]')).firstWhere(
      (part) => part.isNotEmpty,
      orElse: () => 'friend',
    );
    return first;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: ZovaColors.surfaceRaised,
          child: Text(user.avatarEmoji, style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $_firstName 👋',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ZovaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Learning $learningLanguageName · keep it up!',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ZovaColors.textSecondary),
              ),
            ],
          ),
        ),
        _StatChip(
          icon: Icons.local_fire_department,
          color: ZovaColors.warning,
          value: '$streak',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.bolt,
          color: ZovaColors.primary,
          value: '$xp',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: ZovaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.onGoToCourses});

  final VoidCallback onGoToCourses;

  @override
  Widget build(BuildContext context) {
    final languageCode = context
        .watch<LanguageController>()
        .settings
        .learningLanguage;
    return FutureBuilder<Course?>(
      future: SeedContent.courseFor(languageCode),
      builder: (context, snapshot) {
        final course = snapshot.data;
        final hasCourse = course != null;
        final total = course?.totalLessons ?? 0;
        final completed = context
            .watch<AppController>()
            .progress
            .completedLessonsFor(languageCode)
            .length;
        final progress = total == 0 ? 0.0 : completed / total;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.rocket_launch, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Continue learning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                hasCourse
                    ? '$completed of $total lessons completed'
                    : 'A full course for this language is coming soon.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (hasCourse) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ZovaColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: onGoToCourses,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Go to Courses',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GamificationSection extends StatelessWidget {
  const _GamificationSection({
    required this.onQuests,
    required this.onLeague,
    required this.onBadges,
  });

  final VoidCallback onQuests;
  final VoidCallback onLeague;
  final VoidCallback onBadges;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZovaColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Text('❤️', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hearts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Mistakes cost a heart; one refills every 30 min.',
                      style: TextStyle(
                        fontSize: 12,
                        color: ZovaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              HeartsBar(showCount: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _GamificationTile(
                icon: Icons.checklist,
                color: ZovaColors.success,
                label: 'Quests',
                onTap: onQuests,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GamificationTile(
                icon: Icons.emoji_events,
                color: ZovaColors.warning,
                label: 'League',
                onTap: onLeague,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GamificationTile(
                icon: Icons.military_tech,
                color: ZovaColors.secondary,
                label: 'Badges',
                onTap: onBadges,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GamificationTile extends StatelessWidget {
  const _GamificationTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ZovaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ZovaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: ZovaColors.textSecondary),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.onVocabulary,
    required this.onListeningReading,
    required this.onAlphabet,
    required this.onGrammar,
  });

  final VoidCallback onVocabulary;
  final VoidCallback onListeningReading;
  final VoidCallback onAlphabet;
  final VoidCallback onGrammar;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _FeatureCard(
          icon: Icons.translate,
          title: 'Vocabulary',
          faTitle: 'واژه‌آموزی',
          colors: const [ZovaColors.primary, ZovaColors.primaryDark],
          onTap: onVocabulary,
        ),
        _FeatureCard(
          icon: Icons.headphones,
          title: 'Listening & Reading',
          faTitle: 'خواندن و شنیدن',
          colors: const [ZovaColors.secondary, Color(0xFF2B8FD0)],
          onTap: onListeningReading,
        ),
        _FeatureCard(
          icon: Icons.abc,
          title: 'Alphabet & Pronunciation',
          faTitle: 'الفبا و تلفظ',
          colors: const [ZovaColors.warning, Color(0xFFD99A26)],
          onTap: onAlphabet,
        ),
        _FeatureCard(
          icon: Icons.fact_check,
          title: 'Grammar',
          faTitle: 'گرامر',
          colors: const [ZovaColors.success, Color(0xFF1F9A58)],
          onTap: onGrammar,
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.faTitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String faTitle;
  final List<Color> colors;
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ZovaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                faTitle,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 12,
                  color: ZovaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({
    required this.onLeitner,
    required this.onMyWords,
    required this.onShop,
    required this.onSocial,
  });

  final VoidCallback onLeitner;
  final VoidCallback onMyWords;
  final VoidCallback onShop;
  final VoidCallback onSocial;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _QuickTile(
          icon: Icons.style,
          title: 'Leitner Box',
          faTitle: 'لایتنر',
          color: ZovaColors.primary,
          onTap: onLeitner,
        ),
        _QuickTile(
          icon: Icons.bookmark,
          title: 'My Words',
          faTitle: 'کلمات شما',
          color: ZovaColors.success,
          onTap: onMyWords,
        ),
        _QuickTile(
          icon: Icons.storefront,
          title: 'Shop',
          faTitle: 'فروشگاه',
          color: ZovaColors.warning,
          onTap: onShop,
        ),
        _QuickTile(
          icon: Icons.share,
          title: 'Social',
          faTitle: 'شبکه‌ها',
          color: ZovaColors.secondary,
          onTap: onSocial,
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.faTitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String faTitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZovaColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ZovaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      faTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ZovaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: ZovaColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
