import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';
import '../courses/courses_screen.dart';
import '../dictionary/dictionary_screen.dart';
import '../profile/profile_screen.dart';
import '../vocabulary/vocabulary_screen.dart';
import 'home_screen.dart';

/// Main logged-in shell with the primary tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeShellBody();
  }
}

class _HomeShellBody extends StatefulWidget {
  const _HomeShellBody();

  @override
  State<_HomeShellBody> createState() => _HomeShellBodyState();
}

class _HomeShellBodyState extends State<_HomeShellBody> {
  int _index = 0;

  late final List<Widget> _tabs = [
    HomeScreen(onNavigateToTab: (index) => setState(() => _index = index)),
    const CoursesScreen(),
    const VocabularyScreen(),
    const DictionaryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<UiTranslationController?>();
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: ZovaColors.surface,
        indicatorColor: ZovaColors.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? ZovaColors.primary : ZovaColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: context.tr('Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: context.tr('Courses'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.style_outlined),
            selectedIcon: const Icon(Icons.style),
            label: context.tr('Vocabulary'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.translate),
            selectedIcon: const Icon(Icons.translate),
            label: context.tr('Dictionary'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.tr('Profile'),
          ),
        ],
      ),
    );
  }
}
