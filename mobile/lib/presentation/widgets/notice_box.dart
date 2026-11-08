import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Recuadro de aviso: error (rojo) o información (azul), con ícono y texto legible.
class NoticeBox extends StatelessWidget {
  const NoticeBox.error(this.text, {super.key}) : isError = true;

  const NoticeBox.info(this.text, {super.key}) : isError = false;

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError ? scheme.errorContainer : AppColors.infoSurface;
    final foreground = isError ? scheme.onErrorContainer : AppColors.ink;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.small)),
        child: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline,
                color: isError ? foreground : AppColors.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
