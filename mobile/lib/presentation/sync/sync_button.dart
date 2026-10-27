import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'sync_cubit.dart';

/// Ícono de la barra superior: nube con el número de cambios por subir. Al tocarlo, sincroniza.
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
              : state.pending == 0
                  ? 'Todo respaldado'
                  : '${state.pending} cambio(s) por respaldar. Toque para sincronizar';
          return IconButton(
            tooltip: tooltip,
            onPressed: state.syncing ? null : () => context.read<SyncCubit>().syncNow(),
            icon: state.syncing
                ? const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Badge(
                    isLabelVisible: state.pending > 0,
                    label: Text('${state.pending}'),
                    child: Icon(state.pending == 0 ? Icons.cloud_done : Icons.cloud_upload),
                  ),
          );
        },
      );
}
