import 'package:flutter/material.dart';

import '../../core/theme/zova_colors.dart';
import '../books/books_screen.dart';
import '../courses/courses_screen.dart';
import '../dictionary/dictionary_screen.dart';
import '../profile/profile_screen.dart';

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

  static const _tabs = [
    CoursesScreen(),
    BooksScreen(),
    DictionaryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Books',
          ),
          NavigationDestination(
            icon: Icon(Icons.translate),
            selectedIcon: Icon(Icons.translate),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
