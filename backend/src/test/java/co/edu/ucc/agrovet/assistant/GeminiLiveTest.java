package co.edu.ucc.agrovet.assistant;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.web.client.RestClient;

class GeminiLiveTest {

    @Test
    @EnabledIfEnvironmentVariable(named = "GEMINI_LIVE_TEST", matches = "true")
    void respondsWithTheConfiguredRealGeminiModel() {
        String model = System.getenv().getOrDefault("GEMINI_MODEL", "gemini-3.1-flash-lite");
        String apiKey = System.getenv("GEMINI_API_KEY");
        assertThat(apiKey).isNotBlank();
        AssistantProperties properties = new AssistantProperties(
                "gemini",
                apiKey,
                model,
                "https://generativelanguage.googleapis.com",
                Duration.ofSeconds(60),
                20,
                60);

        String answer = new GeminiClient(RestClient.builder(), properties).generate(
                "Responde en español, en una sola frase y sin explicaciones.",
                List.of(new LlmClient.Turn(true, "Di: prueba real de Gemini completada.")),
                null);

        assertThat(answer).isNotBlank();
        System.out.println("Respuesta de Gemini: " + answer);
    }
}
