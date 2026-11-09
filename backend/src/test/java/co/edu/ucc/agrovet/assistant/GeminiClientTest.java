package co.edu.ucc.agrovet.assistant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.time.Duration;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/** Formato real de la petición a Gemini, contra un servidor simulado (sin red ni clave real). */
class GeminiClientTest {

    private final AssistantProperties properties = new AssistantProperties("gemini", "clave-de-prueba",
            "gemini-3.1-flash-lite", "https://gemini.test", Duration.ofSeconds(5), 20, 60);

    @Test
    void sendsKeyInHeaderSystemPromptTurnsAndPhoto() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://gemini.test/v1beta/models/gemini-3.1-flash-lite:generateContent"))
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
        server.expect(requestTo("https://gemini.test/v1beta/models/gemini-3.1-flash-lite:generateContent"))
                .andRespond(withServerError());
        GeminiClient client = new GeminiClient(builder, properties);
        assertThatThrownBy(() -> client.generate("r", List.of(new LlmClient.Turn(true, "x")), null))
                .isInstanceOf(AssistantUnavailableException.class);

        assertThatThrownBy(() -> GeminiClient.extractText(new com.fasterxml.jackson.databind.ObjectMapper()
                .readTree("{\"candidates\":[{\"finishReason\":\"SAFETY\"}]}")))
                .isInstanceOf(AssistantUnavailableException.class);
    }

    @Test
    void retiredModelNotFoundBecomesUnavailableWithoutExposingProviderDetails() {
        AssistantProperties retiredModel = new AssistantProperties("gemini", "clave-de-prueba",
                "gemini-2.5-flash", "https://gemini.test", Duration.ofSeconds(5), 20, 60);
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://gemini.test/v1beta/models/gemini-2.5-flash:generateContent"))
                .andRespond(withStatus(HttpStatus.NOT_FOUND)
                        .contentType(MediaType.APPLICATION_JSON)
                        .body("""
                                {"error":{"code":404,"message":"This model is no longer available to new users."}}
                                """));

        assertThatThrownBy(() -> new GeminiClient(builder, retiredModel)
                .generate("reglas", List.of(new LlmClient.Turn(true, "¿Qué reviso?")), null))
                .isInstanceOf(AssistantUnavailableException.class)
                .hasMessage("Gemini respondió con un error HTTP");
        server.verify();
    }

    @Test
    void providerRateLimitIsReturnedAsAnActionable429() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://gemini.test/v1beta/models/gemini-3.1-flash-lite:generateContent"))
                .andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS)
                        .header(HttpHeaders.RETRY_AFTER, "45")
                        .contentType(MediaType.APPLICATION_JSON)
                        .body("{\"error\":{\"code\":429,\"message\":\"Quota exceeded\"}}"));

        assertThatThrownBy(() -> new GeminiClient(builder, properties)
                .generate("reglas", List.of(new LlmClient.Turn(true, "¿Qué reviso?")), null))
                .isInstanceOf(co.edu.ucc.agrovet.common.TooManyRequestsException.class)
                .hasMessage("El asistente alcanzó el límite de consultas.")
                .satisfies(error -> assertThat(
                        ((co.edu.ucc.agrovet.common.TooManyRequestsException) error).getRetryAfter())
                        .isEqualTo(Duration.ofSeconds(45)));
        server.verify();
    }

    @Test
    void providerOverloadGetsAUserFriendlyMessage() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://gemini.test/v1beta/models/gemini-3.1-flash-lite:generateContent"))
                .andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE)
                        .contentType(MediaType.APPLICATION_JSON)
                        .body("{\"error\":{\"code\":503,\"message\":\"High demand\"}}"));

        assertThatThrownBy(() -> new GeminiClient(builder, properties)
                .generate("reglas", List.of(new LlmClient.Turn(true, "¿Qué reviso?")), null))
                .isInstanceOfSatisfying(AssistantUnavailableException.class, error ->
                        assertThat(error.userMessage())
                                .isEqualTo("El asistente está recibiendo muchas consultas. Intente de nuevo en unos minutos."));
        server.verify();
    }
}
