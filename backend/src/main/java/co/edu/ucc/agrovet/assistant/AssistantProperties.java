package co.edu.ucc.agrovet.assistant;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param provider          "gemini" o "disabled" (variable ASSISTANT_PROVIDER)
 * @param apiKey            clave del proveedor, solo por variable de entorno; nunca llega a la app
 * @param model             modelo del proveedor
 * @param baseUrl           URL base de la API del proveedor
 * @param timeout           espera máxima de la respuesta del proveedor
 * @param maxPerHour        consultas por usuario en una hora
 * @param maxPerDay         consultas por usuario en un día
 */
@ConfigurationProperties("agrovet.assistant")
public record AssistantProperties(String provider, String apiKey, String model, String baseUrl, Duration timeout,
        int maxPerHour, int maxPerDay) {
}
