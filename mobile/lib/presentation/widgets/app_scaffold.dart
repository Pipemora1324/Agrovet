import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
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
          color: AppColors.demoBanner,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.science_outlined, size: 20, color: AppColors.onDemoBanner),
              const SizedBox(width: 8),
              Text(
                'Datos de demostración',
                style: Theme.of(context).textTheme.banner.copyWith(color: AppColors.onDemoBanner),
              ),
            ],
          ),
        ),
      );
}
