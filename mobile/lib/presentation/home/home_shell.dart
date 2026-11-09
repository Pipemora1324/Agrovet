import 'package:flutter/material.dart';

import '../assistant/assistant_hub_screen.dart';
import '../cows/cows_screen.dart';
import '../profile/profile_screen.dart';

/// Pantalla principal de la sesión con la barra inferior: Vacas, Asistente y Perfil. Cada pestaña
/// se construye la primera vez que se abre y conserva su estado al cambiar de pestaña.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};

  static const _tabs = [
    (icon: Icons.pets_outlined, selected: Icons.pets, label: 'Vacas'),
    (icon: Icons.chat_bubble_outline, selected: Icons.chat_bubble, label: 'Asistente'),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Perfil'),
  ];

  Widget _page(int index) => switch (index) {
        0 => const CowsScreen(),
        1 => const AssistantHubScreen(),
        _ => const ProfileScreen(),
      };

  void _select(int index) => setState(() {
        _index = index;
        _visited.add(index);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _tabs.length; i++) _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selected), label: tab.label),
          ],
        ),
      );
}
