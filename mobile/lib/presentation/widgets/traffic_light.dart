import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';

/// Semáforo vertical: la luz activa se enciende con un brillo suave; las demás quedan apagadas.
class TrafficLight extends StatelessWidget {
  const TrafficLight({super.key, required this.level, this.size = 64});

  final RiskLevel? level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final duration = Responsive.motion(context, const Duration(milliseconds: 450));
    return Semantics(
      label: level == null ? 'Semáforo sin resultado' : 'Semáforo en ${level!.label}',
      child: Container(
        padding: EdgeInsets.all(size * 0.18),
        decoration: BoxDecoration(
          color: AppColors.trafficLightBody,
          borderRadius: BorderRadius.circular(size),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final light in [RiskLevel.red, RiskLevel.yellow, RiskLevel.green])
              Padding(
                padding: EdgeInsets.symmetric(vertical: size * 0.08),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: light == level ? light.color : light.color.withValues(alpha: 0.18),
                    boxShadow: light == level
                        ? [BoxShadow(color: light.color.withValues(alpha: 0.7), blurRadius: size * 0.5, spreadRadius: 2)]
                        : const [],
                  ),
                  child: light == level ? Icon(light.icon, color: light.onColor, size: size * 0.5) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta pequeña con el color del último resultado.
class RiskChip extends StatelessWidget {
  const RiskChip({super.key, required this.level});

  final RiskLevel? level;

  @override
  Widget build(BuildContext context) {
    final color = level?.color ?? AppColors.riskNone;
    final onColor = level?.onColor ?? AppColors.inkMuted;
    return AnimatedContainer(
      duration: Responsive.motion(context, const Duration(milliseconds: 300)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level?.icon ?? Icons.help_outline, size: 18, color: onColor),
          const SizedBox(width: 6),
          Text(level?.label ?? 'Sin evaluar', style: Theme.of(context).textTheme.chip.copyWith(color: onColor)),
        ],
      ),
    );
  }
}
