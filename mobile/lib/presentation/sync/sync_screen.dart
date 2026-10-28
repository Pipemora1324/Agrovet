import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/sync/sync_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/big_button.dart';
import 'sync_cubit.dart';

/// Estado del respaldo: qué falta por subir, cuándo se subió por última vez y qué falló.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'Respaldo de datos',
        body: BlocBuilder<SyncCubit, SyncState>(
          builder: (context, state) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CenteredContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusCard(state: state),
                    const SizedBox(height: 16),
                    BigButton(
                      icon: Icons.sync,
                      label: 'Sincronizar ahora',
                      busy: state.syncing,
                      onPressed: state.enabled ? () => context.read<SyncCubit>().syncNow() : null,
                    ),
                    if (state.rejected.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _RejectedCard(issues: state.rejected),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      state.enabled
                          ? 'La app también se sincroniza sola al abrirse, al recuperar la conexión y cada '
                              '15 minutos cuando hay internet. Sus datos nunca se borran del celular.'
                          : 'La sesión de demostración no se sincroniza.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title) = state.hasProblems
        ? (Icons.sync_problem, theme.colorScheme.error, 'Hay un problema')
        : state.pending > 0
            ? (Icons.cloud_upload, const Color(0xFF7A5600), 'Hay cambios por subir')
            : (Icons.cloud_done, AppTheme.primary, 'Todo respaldado');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 40),
                const SizedBox(width: 16),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: color))),
              ],
            ),
            const Divider(height: 32),
            _Row(icon: Icons.pending_actions, label: 'Pendientes', value: '${state.pending}'),
            _Row(
              icon: Icons.history,
              label: 'Última sincronización',
              value: state.lastSyncAt == null ? 'Todavía no' : formatDateTime(state.lastSyncAt!),
            ),
            if (state.lastError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Último intento: ${state.lastError} Sus datos siguen guardados en el celular.',
                  style: TextStyle(fontSize: 17, color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text('$label: ', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 17))),
          ],
        ),
      );
}

class _RejectedCard extends StatelessWidget {
  const _RejectedCard({required this.issues});

  final List<SyncIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.error, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No aceptados por el servidor', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Corrija el dato en la app y se volverá a enviar.', style: theme.textTheme.bodyLarge),
            for (final issue in issues) ...[
              const Divider(height: 24),
              Text('${issue.kind} · ${issue.label}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(issue.reason, style: theme.textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}
