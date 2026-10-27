import 'package:flutter/material.dart';

import '../../core/responsive.dart';

/// Entrada suave (aparece y sube un poco). El retraso escalonado da ritmo a las listas.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final duration = Responsive.motion(context, Duration(milliseconds: 280 + 50 * index.clamp(0, 8)));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
