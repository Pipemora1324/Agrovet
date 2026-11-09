import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../records/daily_record_screen.dart';
import '../sync/sync_button.dart';
import '../sync/sync_cubit.dart';
import '../sync/sync_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/fade_in.dart';
import '../widgets/motion.dart';
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Mis vacas',
      actions: const [SyncButton()],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CowFormScreen())),
        icon: const Icon(Icons.add, size: AppSizes.icon),
        label: const Text('Agregar vaca'),
      ),
      body: BlocBuilder<CowsCubit, CowsState>(
        builder: (context, state) {
          if (state.loading) return const Center(child: CircularProgressIndicator());
          if (state.cows.isEmpty) return const _EmptyCows();
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.columns(constraints.maxWidth);
              final rows = <List<CowSummary>>[
                for (var i = 0; i < state.cows.length; i += columns)
                  state.cows.sublist(i, (i + columns).clamp(0, state.cows.length)),
              ];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                children: [
                  CenteredContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeIn(child: _Greeting(count: state.cows.length)),
                        const SizedBox(height: 16),
                        FadeIn(index: 1, child: _RiskSummary(cows: state.cows)),
                        const SizedBox(height: 12),
                        const FadeIn(index: 2, child: _SyncStatus()),
                        const SizedBox(height: 16),
                        for (var r = 0; r < rows.length; r++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            // Las tarjetas de una fila miden lo mismo, sin alto fijo (letra grande)
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var c = 0; c < columns; c++) ...[
                                    if (c > 0) const SizedBox(width: 12),
                                    Expanded(
                                      child: c < rows[r].length
                                          ? FadeIn(index: 3 + r * columns + c, child: _CowCard(summary: rows[r][c]))
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${today[0].toUpperCase()}${today.substring(1)}', style: theme.textTheme.overline),
        const SizedBox(height: 2),
        Text(count == 1 ? '1 vaca en su hato' : '$count vacas en su hato', style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

/// Cuántas vacas hay en riesgo alto, en alerta y sanas según su última evaluación.
class _RiskSummary extends StatelessWidget {
  const _RiskSummary({required this.cows});

  final List<CowSummary> cows;

  @override
  Widget build(BuildContext context) {
    int count(RiskLevel level) => cows.where((c) => c.lastRisk == level).length;
    final tiles = [
      (RiskLevel.red, 'Riesgo alto', count(RiskLevel.red)),
      (RiskLevel.yellow, 'En alerta', count(RiskLevel.yellow)),
      (RiskLevel.green, 'Sanas', count(RiskLevel.green)),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _SummaryTile(level: tiles[i].$1, label: tiles[i].$2, count: tiles[i].$3)),
          ],
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.level, required this.label, required this.count});

  final RiskLevel level;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $count',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: level.surface, borderRadius: AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(level.icon, color: level.textColor),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: count.toDouble()),
              duration: Responsive.motion(context, AppMotion.bars),
              builder: (context, value, _) =>
                  Text('${value.round()}', style: theme.textTheme.stat.copyWith(color: level.textColor)),
            ),
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: level.textColor)),
          ],
        ),
      ),
    );
  }
}

/// Estado del respaldo en el servidor. En la demostración no se muestra.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context) => BlocBuilder<SyncCubit, SyncState>(
        builder: (context, state) {
          if (!state.enabled) return const SizedBox.shrink();
          final theme = Theme.of(context);
          // Íconos "outlined": los rellenos son los del botón de la nube en la barra superior
          final (icon, text) = state.syncing
              ? (Icons.sync, 'Respaldando sus datos…')
              : state.hasProblems
                  ? (Icons.sync_problem_outlined, 'Hay un problema con el respaldo')
                  : state.pending > 0
                      ? (Icons.cloud_upload_outlined, '${state.pending} cambio(s) por respaldar')
                      : (Icons.cloud_done_outlined, 'Sus datos están respaldados');
          final detail = state.lastSyncAt == null
              ? 'Se respalda solo cuando hay internet.'
              : 'Último respaldo: ${formatDateTime(state.lastSyncAt!)}';
          return PressScale(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(icon, color: state.hasProblems ? AppColors.error : AppColors.primary),
                title: Text(text),
                subtitle: Text(detail, style: theme.textTheme.bodySmall),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen())),
              ),
            ),
          );
        },
      );
}

class _CowCard extends StatelessWidget {
  const _CowCard({required this.summary});

  final CowSummary summary;

  @override
  Widget build(BuildContext context) {
    final cow = summary.cow;
    final theme = Theme.of(context);
    final recordedToday =
        summary.lastRecordDate != null && dateOnly(summary.lastRecordDate!) == dateOnly(DateTime.now());
    final level = summary.lastRisk;
    return PressScale(
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(
            color: level == RiskLevel.red ? level!.color : AppColors.cardBorder,
            width: level == RiskLevel.red ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CowDetailScreen(cowId: cow.id))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    PulseHalo(
                      active: level == RiskLevel.red,
                      color: AppColors.riskRed,
                      child: Hero(tag: 'cow-avatar-${cow.id}', child: CowAvatar(level: level)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cow.name ?? cow.tag,
                              style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            '${cow.tag} · ${cow.productionStatus.label}',
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 32),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RiskChip(level: level),
                    Text(
                      summary.lastRecordDate == null
                          ? 'Sin registros'
                          : 'Registro: ${formatDay(summary.lastRecordDate!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                recordedToday
                    ? OutlinedButton.icon(
                        onPressed: () => _openRecord(context),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Registrado hoy'),
                      )
                    : FilledButton.icon(
                        onPressed: () => _openRecord(context),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Registrar hoy'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRecord(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => DailyRecordScreen(cow: summary.cow)));
}

/// Círculo con el ícono de la vaca y el color del último resultado.
class CowAvatar extends StatelessWidget {
  const CowAvatar({super.key, this.level, this.size = 56});

  final RiskLevel? level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = level?.color ?? AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: level?.surface ?? AppColors.primarySoft,
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(Icons.pets, color: level?.textColor ?? AppColors.primary, size: size * 0.5),
    );
  }
}

class _EmptyCows extends StatelessWidget {
  const _EmptyCows();

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: FadeIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.pets, size: 56, color: AppColors.primary),
                ),
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
