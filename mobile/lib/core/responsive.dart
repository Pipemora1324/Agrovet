import 'package:flutter/material.dart';

/// Puntos de quiebre: celular (< 700 px de ancho) y tableta.
class Responsive {
  static const tabletWidth = 700.0;
  static const maxContentWidth = 720.0;

  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= tabletWidth;

  /// Columnas para las cuadrículas de tarjetas.
  static int columns(double width) {
    if (width >= 1100) return 3;
    if (width >= tabletWidth) return 2;
    return 1;
  }

  /// Duración de las animaciones respetando la opción de reducir movimiento.
  static Duration motion(BuildContext context, Duration normal) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : normal;
}

/// Centra el contenido y limita su ancho en pantallas grandes.
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child, this.maxWidth = Responsive.maxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
