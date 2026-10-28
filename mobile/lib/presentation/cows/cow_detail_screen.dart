import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../history/history_screen.dart';
import '../records/daily_record_screen.dart';
import '../risk/risk_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/big_button.dart';
import '../widgets/fade_in.dart';
import '../widgets/traffic_light.dart';
import 'cow_form_screen.dart';
import 'cows_cubit.dart';
import 'cows_screen.dart';

class CowDetailScreen extends StatelessWidget {
  const CowDetailScreen({super.key, required this.cowId});

  final String cowId;

  Future<void> _confirmDelete(BuildContext context, Cow cow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Dar de baja a ${cow.name ?? cow.tag}?'),
        content: const Text('Dejará de aparecer en la lista. Sus registros se conservan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await CowEditor(context.read<CowRepository>()).delete(cow);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cows = context.read<CowRepository>();
    final inferences = context.read<InferenceRepository>();
    return StreamBuilder<Cow?>(
      stream: cows.watchCow(cowId),
      builder: (context, snapshot) {
        final cow = snapshot.data;
        if (cow == null) {
          return const AppScaffold(title: 'Vaca', body: Center(child: CircularProgressIndicator()));
        }
        return AppScaffold(
          title: cow.name ?? cow.tag,
          actions: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CowFormScreen(cow: cow))),
            ),
            IconButton(
              tooltip: 'Dar de baja',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, cow),
            ),
          ],
          body: StreamBuilder<Inference?>(
            stream: inferences.watchLatest(cowId),
            builder: (context, latest) {
              final summary = _SummaryCard(cow: cow, latest: latest.data);
              final alerts = _PendingAlerts(cowId: cowId);
              final actions = _Actions(cow: cow);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Responsive.isTablet(context)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: FadeIn(child: summary)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FadeIn(index: 1, child: Column(children: [alerts, actions])),
                          ),
                        ],
                      )
                    : CenteredContent(
                        child: Column(
                          children: [
                            FadeIn(child: summary),
                            const SizedBox(height: 16),
                            alerts,
                            FadeIn(index: 1, child: actions),
                          ],
                        ),
                      ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.cow, this.latest});

  final Cow cow;
  final Inference? latest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = cow.birthDate == null ? null : _ageText(cow.birthDate!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(tag: 'cow-avatar-${cow.id}', child: CowAvatar(level: latest?.riskLevel, size: 72)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cow.name ?? cow.tag, style: theme.textTheme.titleLarge),
                      Text(cow.tag, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _InfoRow(icon: Icons.category, label: 'Raza', value: cow.breed ?? '—'),
            _InfoRow(icon: Icons.cake, label: 'Edad', value: age ?? '—'),
            _InfoRow(icon: Icons.child_care, label: 'Partos', value: cow.calvings?.toString() ?? '—'),
            _InfoRow(icon: Icons.water_drop, label: 'Estado', value: cow.productionStatus.label),
            const Divider(height: 32),
            Text('Último resultado', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (latest == null)
              Text('Todavía no se ha evaluado el riesgo.', style: theme.textTheme.bodyLarge)
            else
              Row(
                children: [
                  TrafficLight(level: latest!.riskLevel, size: 26),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(latest!.riskLevel.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: latest!.riskLevel == RiskLevel.yellow
                                    ? const Color(0xFF7A5600)
                                    : latest!.riskLevel.color)),
                        Text('Evaluado: ${formatDay(latest!.windowEndDate)}', style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _ageText(DateTime birth) {
    final now = DateTime.now();
    var months = (now.year - birth.year) * 12 + now.month - birth.month;
    if (now.day < birth.day) months--;
    if (months < 12) return '$months meses';
    final years = months ~/ 12;
    return years == 1 ? '1 año' : '$years años';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text('$label: ', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 17))),
          ],
        ),
      );
}

/// Alertas amarillas o rojas sin atender. Desaparece cuando no hay ninguna.
class _PendingAlerts extends StatelessWidget {
  const _PendingAlerts({required this.cowId});

  final String cowId;

  Future<void> _markAttended(BuildContext context, CowAlert alert) async {
    await context.read<AlertRepository>().markAlertAttended(alert.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alerta marcada como atendida.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<CowAlert>>(
      stream: context.read<AlertRepository>().watchPendingAlerts(cowId),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <CowAlert>[];
        if (alerts.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: alerts.first.riskLevel.color, width: 3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active, color: alerts.first.riskLevel.color, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(alerts.length == 1 ? 'Alerta sin atender' : '${alerts.length} alertas sin atender',
                            style: theme.textTheme.titleMedium),
                      ),
                    ],
                  ),
                  for (final alert in alerts) ...[
                    const Divider(height: 28),
                    Row(
                      children: [
                        RiskChip(level: alert.riskLevel),
                        const SizedBox(width: 12),
                        Expanded(child: Text(formatDay(alert.createdAt), style: theme.textTheme.bodyLarge)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BigButton(
                      icon: Icons.check_circle,
                      label: 'Marcar como atendida',
                      outlined: true,
                      onPressed: () => _markAttended(context, alert),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigButton(
            icon: Icons.edit_note,
            label: 'Registro de hoy',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => DailyRecordScreen(cow: cow))),
          ),
          const SizedBox(height: 12),
          BigButton(
            icon: Icons.traffic,
            label: 'Evaluar riesgo',
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => RiskScreen(cow: cow))),
          ),
          const SizedBox(height: 12),
          BigButton(
            icon: Icons.show_chart,
            label: 'Ver historial',
            outlined: true,
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(cow: cow))),
          ),
        ],
      );
}
