import 'entities.dart';

/// Recomendación básica según el color del semáforo y los síntomas visibles del día.
class RiskAdvice {
  const RiskAdvice({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  static const disclaimer = 'Esta herramienta apoya, no reemplaza al veterinario.';

  static RiskAdvice forLevel(RiskLevel level, {Symptoms symptoms = const Symptoms()}) {
    final advice = switch (level) {
      RiskLevel.green => const RiskAdvice(
          title: 'Siga con el registro diario',
          steps: [
            'Registre temperatura, leche y alimento todos los días.',
            'Mantenga la higiene del ordeño.',
          ],
        ),
      RiskLevel.yellow => const RiskAdvice(
          title: 'Vigile a esta vaca',
          steps: [
            'Revise la ubre y la leche en el próximo ordeño.',
            'Haga la prueba de mastitis (CMT) si la tiene a mano.',
            'Repita el registro mañana y vuelva a evaluar.',
          ],
        ),
      RiskLevel.red => const RiskAdvice(
          title: 'Consulte al veterinario',
          steps: [
            'Llame al veterinario lo antes posible.',
            'Ordéñela de última y separe su leche.',
            'No le aplique antibióticos sin indicación profesional.',
          ],
        ),
    };
    if (!symptoms.any || level == RiskLevel.red) return advice;
    return RiskAdvice(
      title: advice.title,
      steps: [
        'Hay síntomas visibles hoy: consulte al veterinario aunque el semáforo no esté en rojo.',
        ...advice.steps,
      ],
    );
  }
}
