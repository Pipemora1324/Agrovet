import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'sync_cubit.dart';
import 'sync_screen.dart';

/// Ícono de la barra superior: nube con el número de cambios por subir. Al tocarlo abre el estado
/// del respaldo, donde está el botón "Sincronizar ahora".
class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) => BlocConsumer<SyncCubit, SyncState>(
        listenWhen: (previous, current) => current.message != null && previous.message != current.message,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
          context.read<SyncCubit>().messageShown();
        },
        builder: (context, state) {
          if (!state.enabled) return const SizedBox.shrink();
          final tooltip = state.syncing
              ? 'Sincronizando…'
              : state.hasProblems
                  ? 'Hay un problema con el respaldo'
                  : state.pending == 0
                      ? 'Todo respaldado'
                      : '${state.pending} cambio(s) por respaldar';
          return IconButton(
            tooltip: tooltip,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen())),
            icon: state.syncing
                ? const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Badge(
                    isLabelVisible: state.pending > 0,
                    label: Text('${state.pending}'),
                    child: Icon(state.hasProblems
                        ? Icons.sync_problem
                        : state.pending == 0
                            ? Icons.cloud_done
                            : Icons.cloud_upload),
                  ),
          );
        },
      );
}
