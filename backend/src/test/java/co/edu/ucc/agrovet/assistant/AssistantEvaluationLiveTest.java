package co.edu.ucc.agrovet.assistant;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import co.edu.ucc.agrovet.assistant.AssistantDtos.ChatRequest;
import co.edu.ucc.agrovet.assistant.AssistantEvalCases.Attack;
import co.edu.ucc.agrovet.assistant.AssistantEvalCases.Question;
import co.edu.ucc.agrovet.assistant.AssistantEvalCases.RecordedAnswer;
import co.edu.ucc.agrovet.assistant.AssistantEvalCases.Recording;
import co.edu.ucc.agrovet.common.TooManyRequestsException;

/**
 * Corre las 30 preguntas y los 10 ataques contra Gemini con la clave real y graba las respuestas.
 * Usa el mismo prompt del sistema y el mismo armado de la conversación que AssistantService, sin cambiar
 * el modelo ni la temperatura. No corre en el CI: se activa con GEMINI_EVAL=true y GEMINI_API_KEY.
 *
 * <pre>
 * GEMINI_EVAL=true GEMINI_API_KEY=... GEMINI_EVAL_OUTPUT=src/test/resources/asistente/resultados/x.json \
 *   GEMINI_EVAL_LABEL="Prompt original" ./mvnw test -Dtest=AssistantEvaluationLiveTest
 * </pre>
 */
class AssistantEvaluationLiveTest {

    private static final Duration PAUSE = Duration.ofMillis(4500);

    @Test
    @EnabledIfEnvironmentVariable(named = "GEMINI_EVAL", matches = "true")
    void recordsRealAnswers() throws IOException, InterruptedException {
        String apiKey = System.getenv("GEMINI_API_KEY");
        assertThat(apiKey).as("GEMINI_API_KEY").isNotBlank();
        String model = System.getenv().getOrDefault("GEMINI_MODEL", "gemini-3.1-flash-lite");
        Path output = Path.of(System.getenv().getOrDefault("GEMINI_EVAL_OUTPUT", "target/asistente/respuestas.json"));
        String label = System.getenv().getOrDefault("GEMINI_EVAL_LABEL", "Corrida sin etiqueta");
        int repeats = Integer.parseInt(System.getenv().getOrDefault("GEMINI_EVAL_ATTACK_REPEATS", "3"));

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(10));
        factory.setReadTimeout(Duration.ofSeconds(60));
        GeminiClient client = new GeminiClient(RestClient.builder().requestFactory(factory), new AssistantProperties(
                "gemini", apiKey, model, "https://generativelanguage.googleapis.com", Duration.ofSeconds(60), 20, 60));

        List<RecordedAnswer> questions = new ArrayList<>();
        for (Question question : AssistantEvalCases.questions()) {
            questions.add(new RecordedAnswer(question.id(), 1, ask(client, question.request())));
            System.out.println("Pregunta " + question.id() + " lista");
        }
        List<RecordedAnswer> attacks = new ArrayList<>();
        for (Attack attack : AssistantEvalCases.attacks()) {
            for (int rep = 1; rep <= repeats; rep++) {
                attacks.add(new RecordedAnswer(attack.id(), rep, ask(client, attack.request())));
            }
            System.out.println("Ataque " + attack.id() + " listo");
        }

        Recording recording = new Recording(label, "api-real", model,
                LocalDate.now(ZoneId.of("America/Bogota")).toString(),
                AssistantEvalCases.sha256(AssistantPrompt.SYSTEM), 0.3, questions, attacks);
        Files.createDirectories(output.toAbsolutePath().getParent());
        AssistantEvalCases.JSON.writerWithDefaultPrettyPrinter().writeValue(output.toFile(), recording);
        // El resumen va a target/: lo vigente se recalcula siempre desde las respuestas con la rúbrica actual
        Path report = Path.of("target", "asistente", output.getFileName().toString().replace(".json", ".md"));
        Files.createDirectories(report.getParent());
        Files.writeString(report, AssistantEvalReport.markdown(recording), StandardCharsets.UTF_8);
        System.out.println(AssistantEvalReport.markdown(recording));
    }

    /** Llama al proveedor como lo hace la app; reintenta si hay límite de consultas o saturación. */
    private static String ask(GeminiClient client, ChatRequest request) throws InterruptedException {
        for (int attempt = 1; ; attempt++) {
            Thread.sleep(PAUSE.toMillis());
            try {
                return client.generate(AssistantPrompt.SYSTEM, AssistantService.conversation(request), null);
            } catch (TooManyRequestsException e) {
                if (attempt == 5) {
                    throw e;
                }
                Thread.sleep(Math.max(e.getRetryAfter().toMillis(), 20_000L * attempt));
            } catch (AssistantUnavailableException e) {
                if ("El proveedor no devolvió texto".equals(e.getMessage())) {
                    return AssistantRubric.BLOCKED;
                }
                if (attempt == 5) {
                    throw e;
                }
                Thread.sleep(15_000L * attempt);
            }
        }
    }
}
