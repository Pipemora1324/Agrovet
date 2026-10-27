package co.edu.ucc.agrovet.config;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param secret     secreto HS256 en Base64 (mínimo 32 bytes), solo por variable de entorno
 * @param accessTtl  vida del token de acceso (corta)
 * @param refreshTtl vida del refresh token
 */
@ConfigurationProperties("agrovet.jwt")
public record JwtProperties(String secret, String issuer, Duration accessTtl, Duration refreshTtl) {
}
