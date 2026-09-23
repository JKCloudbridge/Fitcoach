import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav `StatefulShellRoute` scaffold shared by both the client and
/// trainer shells (Plan.md's "Two role-gated shells" section) -- same
/// `StatefulNavigationShell` wiring both sibling apps use for their own
/// single shell, just parameterized here since FitCoach needs two distinct
/// tab sets.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.navigationShell, required this.destinations});

  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        destinations: destinations,
      ),
    );
  }
}
