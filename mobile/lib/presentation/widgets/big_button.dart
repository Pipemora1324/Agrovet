import 'package:flutter/material.dart';

/// Botón de acción principal: ancho completo, ícono grande y texto corto.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final content = busy
        ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))
        : Icon(icon, size: 28);
    final action = busy ? null : onPressed;
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(onPressed: action, icon: content, label: Text(label))
          : FilledButton.icon(onPressed: action, icon: content, label: Text(label)),
    );
  }
}
