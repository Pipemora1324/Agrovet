import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../auth/auth_cubit.dart';
import '../sync/sync_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/fade_in.dart';
import '../widgets/traffic_light.dart';
import 'cow_detail_screen.dart';
import 'cow_form_screen.dart';
import 'cows_cubit.dart';

class CowsScreen extends StatelessWidget {
  const CowsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => CowsCubit(context.read<CowRepository>()),
        child: const _CowsView(),
      );
}

class _CowsView extends StatelessWidget {
  const _CowsView();

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Sus datos quedan guardados y cifrados en este celular.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await context.read<AuthCubit>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Mis vacas',
      actions: [
        const SyncButton(),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () => _confirmLogout(context),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CowFormScreen())),
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Agregar vaca'),
      ),
      body: BlocBuilder<CowsCubit, CowsState>(
        builder: (context, state) {
          if (state.loading) return const Center(child: CircularProgressIndicator());
          if (state.cows.isEmpty) return const _EmptyCows();
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.columns(constraints.maxWidth);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 124,
                ),
                itemCount: state.cows.length,
                itemBuilder: (context, index) =>
                    FadeIn(index: index, child: _CowCard(summary: state.cows[index])),
              );
            },
          );
        },
      ),
    );
  }
}

class _CowCard extends StatelessWidget {
  const _CowCard({required this.summary});

  final CowSummary summary;

  @override
  Widget build(BuildContext context) {
    final cow = summary.cow;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CowDetailScreen(cowId: cow.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Hero(tag: 'cow-avatar-${cow.id}', child: CowAvatar(level: summary.lastRisk)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cow.name ?? cow.tag,
                        style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '${cow.tag} · ${cow.productionStatus.label}',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RiskChip(level: summary.lastRisk),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            summary.lastRecordDate == null
                                ? 'Sin registros'
                                : 'Registro: ${formatDay(summary.lastRecordDate!)}',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculo con el ícono de la vaca y el color del último resultado.
class CowAvatar extends StatelessWidget {
  const CowAvatar({super.key, this.level, this.size = 56});

  final RiskLevel? level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = level?.color ?? AppTheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(Icons.pets, color: color, size: size * 0.5),
    );
  }
}

class _EmptyCows extends StatelessWidget {
  const _EmptyCows();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: FadeIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 72, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text('Todavía no hay vacas', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Toque "Agregar vaca" para registrar la primera.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
}
