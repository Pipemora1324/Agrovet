package co.edu.ucc.agrovet.assistant;

import java.util.Locale;
import java.util.stream.Collectors;

import co.edu.ucc.agrovet.assistant.AssistantDtos.CowContext;

/** Instrucciones del asistente y el contexto de la vaca que acompaña cada pregunta. */
final class AssistantPrompt {

    private AssistantPrompt() {
    }

    static final String SYSTEM = """
            Usted es el asistente de AgroVet, una app que ayuda a pequeños ganaderos de Nariño (Colombia) a \
            detectar a tiempo la mastitis en sus vacas de leche.

            Reglas que debe cumplir siempre:
            1. Oriente, no diagnostique. Nunca diga que la vaca tiene o no tiene una enfermedad; hable de \
            señales y de qué revisar.
            2. Si hay una foto, describa solo lo que se ve en ella. No suponga lo que no se ve. Si la foto no \
            muestra una ubre o no se ve bien, dígalo y pida otra con buena luz.
            3. Ante signos graves recomiende llamar al veterinario cuanto antes: fiebre, ubre muy hinchada, \
            caliente, dura o morada, sangre o pus en la leche, vaca decaída o que no come, o si empeora rápido.
            4. No indique medicamentos, antibióticos ni dosis: eso lo decide el veterinario.
            5. Use palabras sencillas y trate al ganadero de "usted". Si usa una palabra técnica, explíquela.
            6. Responda corto: máximo 5 frases o 5 viñetas.
            7. El semáforo de AgroVet es una ayuda, no un diagnóstico; recuérdelo si hace falta.
            8. Si la pregunta no trata del cuidado de las vacas, dígalo con amabilidad y no responda lo demás.
            9. Responda siempre en español.
            10. Escriba en texto plano, sin formato Markdown: nada de asteriscos, almohadillas ni negritas. \
            Si hace una lista, empiece cada línea con un guion.
            """;

    /** Primer mensaje de la conversación: datos mínimos de la vaca, sin datos de la persona. */
    static String context(CowContext context) {
        if (context == null) {
            return "No hay datos de la vaca para esta pregunta.";
        }
        StringBuilder text = new StringBuilder("Datos de la vaca en AgroVet (pueden estar incompletos):\n");
        if (context.riskLevel() != null) {
            text.append("- Último semáforo: ").append(switch (context.riskLevel()) {
                case GREEN -> "verde (sin señales de riesgo)";
                case YELLOW -> "amarillo (alerta temprana)";
                case RED -> "rojo (alto riesgo)";
            });
            if (context.cause() != null) {
                text.append(", indicado por ").append(switch (context.cause()) {
                    case MODEL -> "el modelo de los últimos 14 días";
                    case SYMPTOMS -> "los síntomas del día";
                    case BOTH -> "los síntomas y el modelo";
                });
            }
            text.append('\n');
        }
        if (context.symptomScore() != null) {
            text.append("- Puntaje de síntomas del día: ").append(context.symptomScore()).append('\n');
        }
        if (context.probability() != null) {
            text.append("- Probabilidad estimada por el modelo: ")
                    .append(String.format(Locale.ROOT, "%.0f %%", context.probability() * 100)).append('\n');
        }
        if (context.symptoms() != null && !context.symptoms().isEmpty()) {
            text.append("- Síntomas marcados hoy: ")
                    .append(context.symptoms().stream().map(String::trim).collect(Collectors.joining(", ")))
                    .append('\n');
        }
        return text.toString();
    }
}
