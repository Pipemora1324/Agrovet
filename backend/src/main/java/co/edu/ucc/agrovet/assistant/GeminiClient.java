package co.edu.ucc.agrovet.assistant;

import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.fasterxml.jackson.databind.JsonNode;

import co.edu.ucc.agrovet.common.TooManyRequestsException;

/**
 * Cliente de Gemini (API generateContent). La clave viaja en la cabecera x-goog-api-key, nunca en la
 * URL, y no se escribe en los logs. Tampoco se registran las preguntas ni las respuestas.
 */
public class GeminiClient implements LlmClient {

    private static final Logger log = LoggerFactory.getLogger(GeminiClient.class);
    private static final int MAX_OUTPUT_TOKENS = 500;

    private final RestClient http;
    private final String model;

    public GeminiClient(RestClient.Builder builder, AssistantProperties properties) {
        this.http = builder.baseUrl(properties.baseUrl())
                .defaultHeader("x-goog-api-key", properties.apiKey())
                .build();
        this.model = properties.model();
    }

    @Override
    public String generate(String systemPrompt, List<Turn> turns, byte[] jpeg) {
        List<Map<String, Object>> contents = new ArrayList<>();
        for (int i = 0; i < turns.size(); i++) {
            Turn turn = turns.get(i);
            List<Map<String, Object>> parts = new ArrayList<>();
            boolean last = i == turns.size() - 1;
            if (last && jpeg != null) {
                parts.add(Map.of("inlineData",
                        Map.of("mimeType", "image/jpeg", "data", Base64.getEncoder().encodeToString(jpeg))));
            }
            parts.add(Map.of("text", turn.text()));
            contents.add(Map.of("role", turn.fromUser() ? "user" : "model", "parts", parts));
        }
        Map<String, Object> body = Map.of(
                "systemInstruction", Map.of("parts", List.of(Map.of("text", systemPrompt))),
                "contents", contents,
                "generationConfig", Map.of("maxOutputTokens", MAX_OUTPUT_TOKENS, "temperature", 0.3));
        JsonNode response;
        try {
            response = http.post()
                    .uri("/v1beta/models/{model}:generateContent", model)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(JsonNode.class);
        } catch (HttpStatusCodeException e) {
            log.warn("Gemini respondió HTTP {}", e.getStatusCode().value());
            if (e.getStatusCode().value() == HttpStatus.TOO_MANY_REQUESTS.value()) {
                throw new TooManyRequestsException("El asistente alcanzó el límite de consultas.",
                        retryAfter(e.getResponseHeaders()));
            }
            if (e.getStatusCode().value() == HttpStatus.SERVICE_UNAVAILABLE.value()) {
                throw new AssistantUnavailableException("Gemini está temporalmente saturado.",
                        "El asistente está recibiendo muchas consultas. Intente de nuevo en unos minutos.", e);
            }
            throw new AssistantUnavailableException("Gemini respondió con un error HTTP", e);
        } catch (RestClientException e) {
            log.warn("Gemini no respondió: {}", e.getClass().getSimpleName());
            throw new AssistantUnavailableException("El proveedor no respondió", e);
        }
        return extractText(response);
    }

    private static java.time.Duration retryAfter(HttpHeaders headers) {
        String seconds = headers == null ? null : headers.getFirst(HttpHeaders.RETRY_AFTER);
        try {
            return java.time.Duration.ofSeconds(Math.max(1, Long.parseLong(seconds)));
        } catch (NumberFormatException | NullPointerException e) {
            return java.time.Duration.ofMinutes(1);
        }
    }

    static String extractText(JsonNode response) {
        if (response == null) {
            throw new AssistantUnavailableException("Respuesta vacía del proveedor");
        }
        StringBuilder text = new StringBuilder();
        for (JsonNode part : response.path("candidates").path(0).path("content").path("parts")) {
            text.append(part.path("text").asText(""));
        }
        String answer = text.toString().trim();
        if (answer.isEmpty()) {
            // Bloqueada por los filtros del proveedor o sin contenido
            throw new AssistantUnavailableException("El proveedor no devolvió texto");
        }
        return answer;
    }
}
