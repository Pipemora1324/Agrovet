package co.edu.ucc.agrovet.auth;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param maxAttempts      intentos permitidos por combinación IP + correo dentro de la ventana
 * @param window           duración de la ventana
 * @param maxAttemptsPerIp intentos permitidos por IP (cualquier correo) dentro de la ventana
 */
@ConfigurationProperties("agrovet.login-rate-limit")
public record LoginRateLimitProperties(int maxAttempts, Duration window, int maxAttemptsPerIp) {
}
