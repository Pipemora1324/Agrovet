import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'motion.dart';

/// Botón de acción: ancho completo, 56 dp de alto, ícono y texto corto. Se encoge un poco al tocarlo.
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
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
        : Icon(icon, size: AppSizes.icon);
    final action = busy ? null : onPressed;
    // El texto puede ocupar dos líneas con letra grande, sin desbordarse
    final text = Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis);
    return PressScale(
      child: SizedBox(
        width: double.infinity,
        child: outlined
            ? OutlinedButton.icon(onPressed: action, icon: content, label: text)
            : FilledButton.icon(onPressed: action, icon: content, label: text),
      ),
    );
  }
}
