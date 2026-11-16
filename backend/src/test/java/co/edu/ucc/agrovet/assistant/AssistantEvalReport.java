package co.edu.ucc.agrovet.assistant;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

import co.edu.ucc.agrovet.assistant.AssistantEvalCases.Attack;
import co.edu.ucc.agrovet.assistant.AssistantEvalCases.Question;
import co.edu.ucc.agrovet.assistant.AssistantEvalCases.RecordedAnswer;
import co.edu.ucc.agrovet.assistant.AssistantEvalCases.Recording;
import co.edu.ucc.agrovet.assistant.AssistantRubric.AttackResult;
import co.edu.ucc.agrovet.assistant.AssistantRubric.Score;

/** Califica una corrida grabada con la rúbrica y la resume en tablas Markdown. */
final class AssistantEvalReport {

    static final List<String> CRITERIA = List.of("seguridad", "utilidad", "claridad", "veterinario", "contexto");

    private AssistantEvalReport() {
    }

    record Graded(Map<String, Score> questions, List<AttackGrade> attacks) {

        /** Promedio de un criterio (0 a 2) sobre las preguntas donde se califica. */
        double mean(int criterion) {
            return questions.values().stream().map(s -> s.criteria().get(criterion)).filter(Objects::nonNull)
                    .mapToInt(Integer::intValue).average().orElse(Double.NaN);
        }

        long rated(int criterion) {
            return questions.values().stream().map(s -> s.criteria().get(criterion)).filter(Objects::nonNull)
                    .count();
        }

        double overall() {
            return questions.values().stream().mapToDouble(Score::average).average().orElse(Double.NaN);
        }

        long attacksResisted() {
            return attacks.stream().filter(a -> a.result().resiste()).count();
        }
    }

    record AttackGrade(String id, int repeticion, AttackResult result) {
    }

    static Graded grade(Recording recording) {
        Map<String, Question> questions = AssistantEvalCases.questions().stream()
                .collect(Collectors.toMap(Question::id, Function.identity()));
        Map<String, Attack> attacks = AssistantEvalCases.attacks().stream()
                .collect(Collectors.toMap(Attack::id, Function.identity()));
        Map<String, Score> scores = new LinkedHashMap<>();
        for (RecordedAnswer answer : recording.preguntas()) {
            scores.put(answer.id(), AssistantRubric.score(questions.get(answer.id()), answer.respuesta()));
        }
        List<AttackGrade> attackGrades = new ArrayList<>();
        for (RecordedAnswer answer : recording.ataques()) {
            attackGrades.add(new AttackGrade(answer.id(), answer.repeticion(),
                    AssistantRubric.attack(attacks.get(answer.id()), answer.respuesta())));
        }
        return new Graded(scores, attackGrades);
    }

    static String markdown(Recording recording) {
        Graded graded = grade(recording);
        StringBuilder md = new StringBuilder();
        md.append("## ").append(recording.etiqueta()).append("\n\n")
                .append("Modo: ").append(recording.modo()).append(" · modelo ").append(recording.modelo())
                .append(" · ").append(recording.fecha()).append(" · SHA-256 del prompt ")
                .append(recording.promptSha256(), 0, 12).append("\n\n")
                .append("| Criterio | Promedio (0-2) | Preguntas calificadas |\n|---|---|---|\n");
        for (int i = 0; i < CRITERIA.size(); i++) {
            md.append("| ").append(CRITERIA.get(i)).append(" | ").append(fmt(graded.mean(i))).append(" | ")
                    .append(graded.rated(i)).append(" |\n");
        }
        md.append("| **total** | **").append(fmt(graded.overall())).append("** | ")
                .append(graded.questions().size()).append(" |\n\n")
                .append("Ataques resistidos: ").append(graded.attacksResisted()).append(" de ")
                .append(graded.attacks().size()).append("\n\n### Fallos por pregunta\n\n");
        graded.questions().forEach((id, score) -> {
            if (!score.fallos().isEmpty()) {
                md.append("- ").append(id).append(" (").append(fmt(score.average())).append("): ")
                        .append(String.join("; ", score.fallos())).append('\n');
            }
        });
        md.append("\n### Fallos en ataques\n\n");
        for (AttackGrade attack : graded.attacks()) {
            if (!attack.result().resiste()) {
                md.append("- ").append(attack.id()).append(" #").append(attack.repeticion()).append(": ")
                        .append(String.join("; ", attack.result().fallos())).append('\n');
            }
        }
        return md.toString();
    }

    static String fmt(double value) {
        return String.format(Locale.ROOT, "%.2f", value).replace('.', ',');
    }
}
