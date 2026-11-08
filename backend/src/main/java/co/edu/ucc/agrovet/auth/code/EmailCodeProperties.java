package co.edu.ucc.agrovet.auth.code;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param ttl              vigencia de cada código
 * @param maxAttempts      intentos permitidos por código
 * @param resendCooldown   espera mínima entre dos códigos para el mismo correo
 * @param maxPerDay        códigos que se emiten como máximo por cuenta y propósito en 24 horas;
 *                         con maxAttempts acota los intentos posibles por día
 * @param maxRequestsPerIp solicitudes de código por IP dentro de ipWindow
 * @param ipWindow         ventana del límite por IP
 */
@ConfigurationProperties("agrovet.email-codes")
public record EmailCodeProperties(Duration ttl, int maxAttempts, Duration resendCooldown, int maxPerDay,
        int maxRequestsPerIp, Duration ipWindow) {
}
