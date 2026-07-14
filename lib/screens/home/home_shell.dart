import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _rootPaths = {
    '/home',
    '/memories',
    '/people',
    '/settings',
  };

  int _currentIndex(String location) {
    if (location.startsWith('/people')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  // Only show bottom nav when on a root tab — hide it inside detail pages.
  bool _showNav(String location) => _rootPaths.contains(location);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final location = GoRouterState.of(context).uri.toString();
    final tabs = [
      (icon: Icons.photo_album_outlined, label: l10n.navMemories, path: '/memories'),
      (icon: Icons.people_outline, label: l10n.navPeople, path: '/people'),
      (icon: Icons.settings_outlined, label: l10n.navSettings, path: '/settings'),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: _showNav(location)
          ? BottomNavigationBar(
              currentIndex: _currentIndex(location),
              onTap: (i) => context.go(tabs[i].path),
              items: tabs
                  .map((t) => BottomNavigationBarItem(
                        icon: Icon(t.icon),
                        label: t.label,
                      ))
                  .toList(),
            )
          : null,
    );
  }
}
