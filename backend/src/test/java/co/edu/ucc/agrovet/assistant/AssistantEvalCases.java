package co.edu.ucc.agrovet.assistant;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;

import com.fasterxml.jackson.databind.ObjectMapper;

import co.edu.ucc.agrovet.assistant.AssistantDtos.ChatRequest;
import co.edu.ucc.agrovet.assistant.AssistantDtos.CowContext;
import co.edu.ucc.agrovet.assistant.AssistantDtos.HistoryTurn;

/** Casos de la evaluación del asistente (src/test/resources/asistente) y respuestas grabadas. */
final class AssistantEvalCases {

    static final String DIR = "/asistente/";
    static final ObjectMapper JSON = new ObjectMapper();

    private AssistantEvalCases() {
    }

    /** Pregunta de un ganadero con lo que se espera de la respuesta. */
    record Question(String id, String categoria, String pregunta, CowContext contexto, String veterinario,
            boolean urgente, List<List<String>> debeMencionar, List<String> contextoEsperado) {

        Question {
            debeMencionar = debeMencionar == null ? List.of() : debeMencionar;
            contextoEsperado = contextoEsperado == null ? List.of() : contextoEsperado;
        }

        ChatRequest request() {
            return new ChatRequest(pregunta, contexto, List.of(), null);
        }
    }

    /** Intento de inyección de instrucciones o de pedir dosis o diagnósticos. */
    record Attack(String id, String tipo, String pregunta, CowContext contexto, List<HistoryTurn> historial,
            List<String> noDebeContener, boolean debeRechazar) {

        Attack {
            historial = historial == null ? List.of() : historial;
            noDebeContener = noDebeContener == null ? List.of() : noDebeContener;
        }

        ChatRequest request() {
            return new ChatRequest(pregunta, contexto, historial, null);
        }
    }

    record QuestionSet(String descripcion, List<Question> preguntas) {
    }

    record AttackSet(String descripcion, List<Attack> ataques) {
    }

    record RecordedAnswer(String id, int repeticion, String respuesta) {
    }

    /** Respuestas de una corrida. modo: "api-real" o "simulado". */
    record Recording(String etiqueta, String modo, String modelo, String fecha, String promptSha256,
            double temperatura, List<RecordedAnswer> preguntas, List<RecordedAnswer> ataques) {
    }

    static List<Question> questions() {
        return read("preguntas.json", QuestionSet.class).preguntas();
    }

    static List<Attack> attacks() {
        return read("ataques.json", AttackSet.class).ataques();
    }

    static Recording recording(String name) {
        return read("resultados/" + name, Recording.class);
    }

    static String sha256(String text) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static <T> T read(String name, Class<T> type) {
        try (InputStream in = AssistantEvalCases.class.getResourceAsStream(DIR + name)) {
            if (in == null) {
                throw new IllegalStateException("No existe el recurso " + DIR + name);
            }
            return JSON.readValue(in, type);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
