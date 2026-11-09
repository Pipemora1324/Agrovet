package co.edu.ucc.agrovet.config;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Orígenes permitidos por CORS. Vacío = ningún origen de navegador puede llamar a la API. */
@ConfigurationProperties("agrovet.cors")
public record CorsProperties(List<String> allowedOrigins) {

    public CorsProperties {
        allowedOrigins = allowedOrigins == null ? List.of()
                : allowedOrigins.stream().map(String::trim).filter(s -> !s.isEmpty()).toList();
        // CORS restrictivo: hay que nombrar cada origen
        if (allowedOrigins.stream().anyMatch(origin -> origin.contains("*"))) {
            throw new IllegalStateException("CORS_ALLOWED_ORIGINS no admite '*': escriba cada origen permitido.");
        }
    }
}
