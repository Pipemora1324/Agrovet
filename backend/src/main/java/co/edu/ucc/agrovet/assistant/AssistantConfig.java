package co.edu.ucc.agrovet.assistant;

import java.net.http.HttpClient;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/** Elige el proveedor según ASSISTANT_PROVIDER. Sin clave, el asistente queda apagado (503), no falla el arranque. */
@Configuration
class AssistantConfig {

    private static final Logger log = LoggerFactory.getLogger(AssistantConfig.class);

    @Bean
    LlmClient llmClient(AssistantProperties properties) {
        String provider = properties.provider() == null ? "" : properties.provider().trim().toLowerCase();
        boolean hasKey = properties.apiKey() != null && !properties.apiKey().isBlank();
        if ("gemini".equals(provider) && hasKey) {
            JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(
                    HttpClient.newBuilder().connectTimeout(properties.timeout()).build());
            factory.setReadTimeout(properties.timeout());
            log.info("Asistente con Gemini ({})", properties.model());
            return new GeminiClient(RestClient.builder().requestFactory(factory), properties);
        }
        log.info("Asistente desactivado (ASSISTANT_PROVIDER={}, clave {})", provider, hasKey ? "presente" : "ausente");
        return (systemPrompt, turns, jpeg) -> {
            throw new AssistantUnavailableException("Asistente no configurado");
        };
    }
}
