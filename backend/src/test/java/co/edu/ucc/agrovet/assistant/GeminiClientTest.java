package co.edu.ucc.agrovet.assistant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.time.Duration;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/** Formato real de la petición a Gemini, contra un servidor simulado (sin red ni clave real). */
class GeminiClientTest {

    private final AssistantProperties properties = new AssistantProperties("gemini", "clave-de-prueba",
            "gemini-2.5-flash", "https://gemini.test", Duration.ofSeconds(5), 20, 60);

    @Test
    void sendsKeyInHeaderSystemPromptTurnsAndPhoto() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://gemini.test/v1beta/models/gemini-2.5-flash:generateContent"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header("x-goog-api-key", "clave-de-prueba"))
                .andExpect(jsonPath("$.systemInstruction.parts[0].text").value("reglas"))
                .andExpect(jsonPath("$.contents[0].role").value("user"))
                .andExpect(jsonPath("$.contents[1].role").value("model"))
                .andExpect(jsonPath("$.contents[2].parts[0].inlineData.mimeType").value("image/jpeg"))
                .andExpect(jsonPath("$.contents[2].parts[1].text").value("¿Cómo la ve?"))
                .andRespond(withSuccess("""
                        {"candidates":[{"content":{"parts":[{"text":"Se ve "},{"text":"enrojecida."}]}}]}
                        """, MediaType.APPLICATION_JSON));

        String answer = new GeminiClient(builder, properties).generate("reglas", List.of(
                new LlmClient.Turn(true, "contexto"), new LlmClient.Turn(false, "Entendido"),
                new LlmClient.Turn(true, "¿Cómo la ve?")), new byte[] { 1, 2, 3 });

        assertThat(answer).isEqualTo("Se ve enrojecida.");
        server.verify();
    }

    @Test
    void errorsAndBlockedAnswersBecomeUnavailable() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://gemini.test/v1beta/models/gemini-2.5-flash:generateContent"))
                .andRespond(withServerError());
        GeminiClient client = new GeminiClient(builder, properties);
        assertThatThrownBy(() -> client.generate("r", List.of(new LlmClient.Turn(true, "x")), null))
                .isInstanceOf(AssistantUnavailableException.class);

        assertThatThrownBy(() -> GeminiClient.extractText(new com.fasterxml.jackson.databind.ObjectMapper()
                .readTree("{\"candidates\":[{\"finishReason\":\"SAFETY\"}]}")))
                .isInstanceOf(AssistantUnavailableException.class);
    }
}
