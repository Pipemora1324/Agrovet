/// Textos de la pantalla "Acerca del modelo". Todas las cifras salen de ml/README.md (resultados del
/// LSTM, líneas base y evaluaciones de las dos CNN); test/domain/model_facts_test.dart comprueba que
/// cada número aparezca allí tal cual. Si cambian los informes, se cambia aquí.
class ModelFacts {
  ModelFacts._();

  /// Aviso fijo, arriba de la pantalla.
  static const disclaimer = 'No es diagnóstico, no validado con datos reales.';

  static const sections = <ModelFactSection>[
    ModelFactSection(
      title: 'Semáforo de riesgo (LSTM)',
      paragraphs: [
        'Una red LSTM revisa los últimos 14 días de cada vaca y da una probabilidad de riesgo de '
            'mastitis en los próximos días.',
        'Variables de cada día: temperatura (°C), leche (L) y alimento (kg). Cada una se compara con la '
            'base de la vaca, la media de los primeros 7 días de la ventana. Un dato vacío o fuera de '
            'rango toma el último valor válido; si una variable tiene menos de 10 días válidos, no se '
            'evalúa.',
        'Entrenado con datos SINTÉTICOS: 600 vacas simuladas durante 60 días. Todavía no hay registros '
            'reales de fincas.',
      ],
      facts: [
        ModelFact('Prueba sintética', '90 vacas, 3514 ventanas'),
        ModelFact('F1', '0,49 (IC 95 %: 0,40–0,57)'),
        ModelFact('AUC', '0,89 (IC 95 %: 0,87–0,91)'),
        ModelFact('Sensibilidad', '0,46'),
        ModelFact('Precisión', '0,53'),
        ModelFact('Vacas enfermas avisadas 1–5 días antes', '30 de 32'),
        ModelFact('Vacas sanas con al menos una alerta roja', '31 de 58'),
      ],
      notes: [
        'La meta del proyecto es F1 ≥ 0,80. Con estos datos el modelo no la alcanza, y como los datos son '
            'sintéticos, estas cifras no dicen cómo funcionaría en una finca real.',
        'Semáforo: verde por debajo de 0,427, amarillo de 0,427 a menos de 0,854 y rojo desde 0,854. El '
            'umbral no debe leerse como una probabilidad calibrada.',
      ],
    ),
    ModelFactSection(
      title: 'Frente a modelos más simples (misma prueba sintética)',
      paragraphs: [],
      facts: [
        ModelFact('LSTM de la app', 'F1 0,49 · AUC 0,89'),
        ModelFact('Umbral de temperatura', 'F1 0,33 · AUC 0,83'),
        ModelFact('Regresión logística', 'F1 0,43 · AUC 0,86'),
        ModelFact('Random forest', 'F1 0,44 · AUC 0,87'),
      ],
      notes: [
        'El LSTM supera con claridad al umbral de temperatura: la leche y el alimento aportan información. '
            'Frente a la regresión logística y al random forest la ventaja es chica.',
      ],
    ),
    ModelFactSection(
      title: 'Leche (experimental)',
      paragraphs: [
        'Red MobileNetV2 que mira la foto de un pozo de la paleta de ordeño (160 px) y dice si la leche se '
            've normal o anormal (sangre, grumos o aguada). Solo está en el APK de demostración.',
        'Entrenada y evaluada con un solo conjunto de datos público: 453 imágenes y 640 pozos, una paleta y '
            'un tipo de celular. Las etiquetas son del autor del conjunto, sin laboratorio.',
      ],
      facts: [
        ModelFact('Sensibilidad', '0,978'),
        ModelFact('Especificidad', '1,000'),
        ModelFact('AUC', '0,9996'),
        ModelFact('AUC sin ver la leche (solo el contexto)', '0,912'),
      ],
      notes: [
        'Una red que no ve ninguna leche ya separa los casos: la cifra alta no se puede atribuir solo al '
            'color de la leche. Con fotos nuevas puede fallar, y el resultado cambia mucho según cómo se '
            'encuadre el pozo.',
        'El aspecto de la leche solo cambia en la mastitis clínica; la subclínica no se ve en una foto.',
      ],
    ),
    ModelFactSection(
      title: 'Ubre (experimental)',
      paragraphs: [
        'Red MobileNetV2 que mira una foto de la ubre (224 px). Viene apagada en la app normal; el APK de '
            'demostración la enciende para mostrarla, con el aviso "Resultado orientativo, no es '
            'diagnóstico".',
        'Entrenada con 117 fotos de un conjunto público. Las etiquetas no tienen confirmación veterinaria.',
      ],
      facts: [
        ModelFact('Sensibilidad', '0,77'),
        ModelFact('Especificidad', '0,89'),
        ModelFact('AUC', '0,87'),
        ModelFact('AUC viendo solo el fondo (ubre tapada)', '0,75'),
        ModelFact('Sensibilidad solo en fotos de establo', '0,55–0,58'),
      ],
      notes: [
        'El modelo aprende parte del entorno y no de la ubre: en fotos de establo se le escapa casi la '
            'mitad de las mastitis. La recomendación es no encenderlo hasta tener fotos confirmadas por '
            'un veterinario.',
      ],
    ),
  ];
}

class ModelFactSection {
  const ModelFactSection({required this.title, required this.paragraphs, required this.facts, required this.notes});

  final String title;
  final List<String> paragraphs;
  final List<ModelFact> facts;
  final List<String> notes;

  /// Todo el texto de la sección, para revisarlo en las pruebas.
  Iterable<String> get allText sync* {
    yield title;
    yield* paragraphs;
    for (final fact in facts) {
      yield fact.label;
      yield fact.value;
    }
    yield* notes;
  }
}

class ModelFact {
  const ModelFact(this.label, this.value);

  final String label;
  final String value;
}
