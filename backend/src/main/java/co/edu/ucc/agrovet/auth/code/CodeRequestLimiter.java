package co.edu.ucc.agrovet.auth.code;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Component;

import co.edu.ucc.agrovet.common.TooManyRequestsException;

/**
 * Límite en memoria para pedir códigos por correo. Se aplica por correo escrito, exista o no la
 * cuenta, así que un 429 no revela nada. Basta para una sola instancia del backend.
 * <ul>
 * <li>Espera mínima entre dos solicitudes para el mismo correo y propósito.</li>
 * <li>Máximo de solicitudes por IP dentro de una ventana.</li>
 * </ul>
 */
@Component
public class CodeRequestLimiter {

    private static final int CLEANUP_THRESHOLD = 10_000;

    private final EmailCodeProperties properties;
    private final Clock clock;
    private final Map<String, Instant> lastRequest = new ConcurrentHashMap<>();
    private final Map<String, IpWindow> perIp = new ConcurrentHashMap<>();

    public CodeRequestLimiter(EmailCodeProperties properties, Clock clock) {
        this.properties = properties;
        this.clock = clock;
    }

    /** Registra la solicitud o lanza TooManyRequestsException con el tiempo de espera. */
    public void acquire(String ip, String email, CodePurpose purpose) {
        Instant now = clock.instant();
        cleanup(now);
        IpWindow window = perIp.compute(ip, (k, current) ->
                current == null || current.isOver(now, properties.ipWindow()) ? new IpWindow(now) : current);
        synchronized (window) {
            if (window.count >= properties.maxRequestsPerIp()) {
                throw tooMany(Duration.between(now, window.start.plus(properties.ipWindow())));
            }
            String key = purpose + "|" + email.toLowerCase(Locale.ROOT);
            Instant previous = lastRequest.get(key);
            if (previous != null && now.isBefore(previous.plus(properties.resendCooldown()))) {
                throw tooMany(Duration.between(now, previous.plus(properties.resendCooldown())));
            }
            lastRequest.put(key, now);
            window.count++;
        }
    }

    /** Como acquire, pero sin excepción: para envíos automáticos (por ejemplo, al intentar ingresar). */
    public boolean tryAcquire(String ip, String email, CodePurpose purpose) {
        try {
            acquire(ip, email, purpose);
            return true;
        } catch (TooManyRequestsException e) {
            return false;
        }
    }

    private void cleanup(Instant now) {
        if (lastRequest.size() > CLEANUP_THRESHOLD) {
            lastRequest.values().removeIf(at -> !now.isBefore(at.plus(properties.resendCooldown())));
        }
        if (perIp.size() > CLEANUP_THRESHOLD) {
            perIp.values().removeIf(w -> w.isOver(now, properties.ipWindow()));
        }
    }

    private static TooManyRequestsException tooMany(Duration retryAfter) {
        return new TooManyRequestsException("Espere un momento antes de pedir otro código.", retryAfter);
    }

    private static final class IpWindow {
        private final Instant start;
        private int count;

        IpWindow(Instant start) {
            this.start = start;
        }

        boolean isOver(Instant now, Duration length) {
            return !now.isBefore(start.plus(length));
        }
    }
}
