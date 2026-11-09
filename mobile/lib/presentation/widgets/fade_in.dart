import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Entrada suave: aparece y sube un poco (~550 ms). El índice escalona la entrada en las listas.
/// Con "reducir movimiento" el contenido aparece de inmediato.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // El retraso escalonado va dentro del mismo controlador (sin temporizadores sueltos)
    final delay = AppMotion.stagger * widget.index.clamp(0, 8);
    final total = delay + AppMotion.entrance;
    _controller = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Opacity(
          opacity: _curve.value,
          child: Transform.translate(offset: Offset(0, 24 * (1 - _curve.value)), child: child),
        ),
        child: widget.child,
      );
}
