import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';

/// Controlador que se repite mientras las animaciones de ambiente estén activas; si no, hace un
/// ciclo. Con "reducir movimiento" no se mueve.
mixin _AmbientLoop<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController loop = AnimationController(vsync: this, duration: loopDuration);
  bool _configured = false;

  Duration get loopDuration;

  /// true: ida y vuelta (formas flotantes); false: vuelve a empezar (pulso, brillo).
  bool get reverse => false;

  /// false para detenerla (por ejemplo, el pulso solo en riesgo alto).
  bool get active => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_configured) {
      _configured = true;
      _apply();
    }
  }

  void _apply() {
    if (!active || MediaQuery.of(context).disableAnimations) {
      loop.stop();
      loop.value = 0;
    } else if (AppMotion.ambient) {
      loop.repeat(reverse: reverse);
    } else {
      loop.forward(from: 0);
    }
  }

  void restartLoop() => _apply();

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

/// Se encoge un poco (0,97) mientras se presiona, como un botón físico.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _pressed ? AppMotion.pressedScale : 1,
          duration: Responsive.motion(context, AppMotion.press),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Barra horizontal que crece desde cero hasta [fraction] (0 a 1).
class GrowBar extends StatelessWidget {
  const GrowBar({super.key, required this.fraction, required this.color, this.height = 14, this.delay = 0});

  final double fraction;
  final Color color;
  final double height;

  /// Posición en una lista, para escalonar el crecimiento.
  final int delay;

  @override
  Widget build(BuildContext context) {
    final target = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: AppColors.chartBarTrack,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: Responsive.motion(context, AppMotion.bars + AppMotion.stagger * delay),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => FractionallySizedBox(
            widthFactor: value,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barras verticales de varios días que crecen desde abajo. Un día sin dato queda vacío.
class GrowColumns extends StatelessWidget {
  const GrowColumns({
    super.key,
    required this.values,
    required this.color,
    this.height = 96,
    this.estimated = const {},
  });

  final List<double?> values;
  final Color color;
  final double height;

  /// Índices de los valores estimados (se dibujan más claros).
  final Set<int> estimated;

  @override
  Widget build(BuildContext context) {
    final present = values.whereType<double>();
    final max = present.isEmpty ? 1.0 : math.max(present.reduce(math.max), 0.001);
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Responsive.motion(context, AppMotion.bars),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: values[i] == null
                      ? Container(height: 4, color: AppColors.chartBarTrack)
                      : Container(
                          height: math.max(4, height * (values[i]! / max) * t),
                          decoration: BoxDecoration(
                            color: estimated.contains(i) ? color.withValues(alpha: 0.45) : color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Anillo con el porcentaje en el centro; el arco se llena al aparecer.
class PercentRing extends StatelessWidget {
  const PercentRing({super.key, required this.value, required this.color, this.size = 132, this.center});

  /// 0 a 1, o null si no hay porcentaje (se muestra [center]).
  final double? value;
  final Color color;
  final double size;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value ?? 0),
        duration: Responsive.motion(context, AppMotion.chart),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          painter: _RingPainter(fraction: t, color: color, track: AppColors.chartBarTrack),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(size * 0.16),
              child: FittedBox(
                child: center ??
                    Text('${(t * 100).round()} %', style: theme.textTheme.stat.copyWith(color: color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.track});

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arc, 0, math.pi * 2, false, base);
    if (fraction > 0) {
      canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * fraction, false,
          base..color = color..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

/// Halo que late alrededor de [child] (riesgo alto). Inactivo, solo muestra el hijo.
class PulseHalo extends StatefulWidget {
  const PulseHalo({super.key, required this.child, required this.color, this.active = true});

  final Widget child;
  final Color color;
  final bool active;

  @override
  State<PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<PulseHalo> with SingleTickerProviderStateMixin, _AmbientLoop {
  @override
  Duration get loopDuration => AppMotion.pulse;

  @override
  bool get active => widget.active;

  @override
  void didUpdateWidget(PulseHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) restartLoop();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) {
        final t = Curves.easeOut.transform(loop.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                spreadRadius: 14 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Tres puntos que suben y bajan: "el asistente está escribiendo".
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color = AppColors.primary});

  final Color color;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin, _AmbientLoop {
  @override
  Duration get loopDuration => const Duration(milliseconds: 1100);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: loop,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(0, -6 * math.max(0, math.sin((loop.value - i * 0.18) * math.pi * 2))),
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      );
}

/// Botón principal con un brillo que lo recorre de lado a lado.
class ShineButton extends StatefulWidget {
  const ShineButton({super.key, required this.icon, required this.label, required this.onPressed, this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  State<ShineButton> createState() => _ShineButtonState();
}

class _ShineButtonState extends State<ShineButton> with SingleTickerProviderStateMixin, _AmbientLoop {
  @override
  Duration get loopDuration => AppMotion.shine;

  @override
  Widget build(BuildContext context) {
    final action = widget.busy ? null : widget.onPressed;
    return PressScale(
      child: SizedBox(
        width: double.infinity,
        child: ClipRRect(
          borderRadius: AppRadius.button,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: action,
                  icon: widget.busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.onPrimary),
                        )
                      : Icon(widget.icon, size: AppSizes.icon),
                  label: Text(widget.label),
                ),
              ),
              // El brillo no recibe toques
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: loop,
                    builder: (context, _) {
                      // Recorre el botón en el primer 40 % del ciclo y luego descansa
                      final t = (loop.value / 0.4).clamp(0.0, 1.0);
                      if (t == 0 || t == 1) return const SizedBox.shrink();
                      return FractionalTranslation(
                        translation: Offset(-1 + 2.2 * t, 0),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.transparent, AppColors.shine, AppColors.transparent],
                              stops: [0.3, 0.5, 0.7],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado verde con el borde inferior curvo y formas que flotan despacio.
class CurvedHero extends StatelessWidget {
  const CurvedHero({super.key, required this.child, this.minHeight = 220});

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _WaveClipper(),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: FloatingShapes()),
              Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 56), child: child),
            ],
          ),
        ),
      );
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    return Path()
      ..lineTo(0, h - 36)
      ..quadraticBezierTo(w * 0.25, h, w * 0.5, h - 22)
      ..quadraticBezierTo(w * 0.78, h - 48, w, h - 18)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) => false;
}

/// Círculos y una hoja translúcidos que se desplazan despacio (decoración del encabezado).
class FloatingShapes extends StatefulWidget {
  const FloatingShapes({super.key});

  @override
  State<FloatingShapes> createState() => _FloatingShapesState();
}

class _FloatingShapesState extends State<FloatingShapes> with SingleTickerProviderStateMixin, _AmbientLoop {
  @override
  Duration get loopDuration => AppMotion.float;

  @override
  bool get reverse => true;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: AnimatedBuilder(
          animation: loop,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(loop.value);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _shape(right: -30 + 14 * t, top: -24 + 10 * t, size: 140, color: AppColors.heroShape),
                _shape(left: -40 + 12 * t, bottom: 10 - 14 * t, size: 110, color: AppColors.heroShape),
                _shape(right: 70 - 18 * t, bottom: 50 + 12 * t, size: 34, color: AppColors.heroShapeStrong),
                Positioned(
                  left: 40 + 16 * t,
                  top: 30 + 8 * t,
                  child: Transform.rotate(
                    angle: -0.4 + 0.3 * t,
                    child: const Icon(Icons.eco, size: 40, color: AppColors.heroShapeStrong),
                  ),
                ),
                Positioned(
                  right: 30 + 10 * t,
                  top: 90 - 10 * t,
                  child: const Icon(Icons.wb_sunny, size: 28, color: AppColors.sun),
                ),
              ],
            );
          },
        ),
      );

  Widget _shape({double? left, double? right, double? top, double? bottom, required double size, required Color color}) =>
      Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      );
}

/// Revela su contenido de izquierda a derecha, como si se dibujara (gráficas).
class DrawIn extends StatelessWidget {
  const DrawIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Responsive.motion(context, AppMotion.chart),
        curve: Curves.easeInOutCubic,
        builder: (context, t, child) => ClipRect(
          child: Align(alignment: Alignment.centerLeft, widthFactor: t, child: child),
        ),
        child: child,
      );
}

/// Círculo verde con un visto que se dibuja (pantalla final del registro).
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Responsive.motion(context, const Duration(milliseconds: 800)),
        curve: Curves.easeOutBack,
        builder: (context, t, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _CheckPainter(t.clamp(0.0, 1.2))),
        ),
      );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 * math.min(1, t * 1.4).toDouble();
    canvas.drawCircle(center, radius, Paint()..color = AppColors.riskGreenSurface);
    canvas.drawCircle(
        center,
        radius * 0.78,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill);
    final progress = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    if (progress == 0) return;
    final a = Offset(size.width * 0.32, size.height * 0.52);
    final b = Offset(size.width * 0.45, size.height * 0.65);
    final c = Offset(size.width * 0.70, size.height * 0.38);
    final path = Path()..moveTo(a.dx, a.dy);
    if (progress < 0.4) {
      final p = Offset.lerp(a, b, progress / 0.4)!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(b.dx, b.dy);
      final p = Offset.lerp(b, c, (progress - 0.4) / 0.6)!;
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.onPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.08
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
