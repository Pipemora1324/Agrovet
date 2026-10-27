import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/session.dart';

/// Scaffold común: en la sesión de demostración muestra siempre el rótulo bajo la barra superior.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final isDemo = context.read<Session?>()?.isDemo ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        bottom: isDemo ? const DemoBanner() : null,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: body),
    );
  }
}

class DemoBanner extends StatelessWidget implements PreferredSizeWidget {
  const DemoBanner({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Datos de demostración',
        child: Container(
          height: preferredSize.height,
          color: const Color(0xFFFFE082),
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science_outlined, size: 20, color: Color(0xFF3E2C00)),
              SizedBox(width: 8),
              Text(
                'Datos de demostración',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF3E2C00)),
              ),
            ],
          ),
        ),
      );
}
