package co.edu.ucc.agrovet.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Component;

/**
 * Límite de intentos de login en memoria, por ventana fija. Cuenta todos los intentos (no solo
 * los fallidos) por IP + correo y por IP; un login exitoso limpia el contador IP + correo.
 * Basta para una sola instancia del backend; con varias habría que moverlo a la base o a Redis.
 */
@Component
public class LoginRateLimiter {

    private static final int CLEANUP_THRESHOLD = 10_000;

    private final LoginRateLimitProperties properties;
    private final Clock clock;
    private final Map<String, Window> windows = new ConcurrentHashMap<>();

    public LoginRateLimiter(LoginRateLimitProperties properties, Clock clock) {
        this.properties = properties;
        this.clock = clock;
    }

    /** Registra un intento; lanza TooManyLoginAttemptsException si se superó algún límite. */
    public void registerAttempt(String ip, String email) {
        Instant now = clock.instant();
        if (windows.size() > CLEANUP_THRESHOLD) {
            windows.values().removeIf(w -> w.isOver(now, properties.window()));
        }
        Window pair = hit(pairKey(ip, email), now);
        Window perIp = hit("ip:" + ip, now);
        if (pair.count > properties.maxAttempts()) {
            throw new TooManyLoginAttemptsException(pair.retryAfter(now, properties.window()));
        }
        if (perIp.count > properties.maxAttemptsPerIp()) {
            throw new TooManyLoginAttemptsException(perIp.retryAfter(now, properties.window()));
        }
    }

    public void reset(String ip, String email) {
        windows.remove(pairKey(ip, email));
    }

    private Window hit(String key, Instant now) {
        return windows.compute(key, (k, current) -> {
            Window window = current == null || current.isOver(now, properties.window()) ? new Window(now) : current;
            window.count++;
            return window;
        });
    }

    private static String pairKey(String ip, String email) {
        return "pair:" + ip + "|" + email.toLowerCase(Locale.ROOT);
    }

    private static final class Window {
        private final Instant start;
        private int count;

        Window(Instant start) {
            this.start = start;
        }

        boolean isOver(Instant now, Duration length) {
            return !now.isBefore(start.plus(length));
        }

        Duration retryAfter(Instant now, Duration length) {
            return Duration.between(now, start.plus(length));
        }
    }
}
