/// Consejos fijos que la app muestra sin internet, cuando no se puede consultar al asistente.
/// Son pautas generales de manejo; no reemplazan al veterinario.
class AssistantTips {
  AssistantTips._();

  static const notice = 'Orientación de un asistente de IA, no es un diagnóstico.';

  static const offline = <(String, List<String>)>[
    (
      'Si sospecha mastitis',
      [
        'Separe a la vaca y ordéñela de última, con otro balde, para no contagiar a las demás.',
        'No mezcle su leche con la del resto ni la venda hasta que el veterinario la revise.',
        'Revise los cuatro cuartos: calor, hinchazón, dolor y cómo sale la leche.',
      ],
    ),
    (
      'Higiene del ordeño',
      [
        'Lávese las manos y use guantes si puede.',
        'Limpie y seque cada pezón con una toalla limpia para cada vaca.',
        'Despunte: mire los primeros chorros en un recipiente oscuro para ver grumos o sangre.',
        'Después de ordeñar, sumerja los pezones en un desinfectante (sellador) y mantenga a la vaca de pie un rato.',
      ],
    ),
    (
      'Llame al veterinario si',
      [
        'Hay sangre, pus o grumos grandes en la leche.',
        'La ubre está muy hinchada, caliente, dura o morada.',
        'La vaca tiene fiebre, está decaída o no quiere comer.',
        'Los signos empeoran de un día para otro o no mejoran.',
      ],
    ),
  ];
}
