package co.edu.ucc.agrovet.assistant;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Component;

import co.edu.ucc.agrovet.common.TooManyRequestsException;

/**
 * Límite de consultas al asistente por usuario (por hora y por día), en memoria. Cada consulta cuesta
 * dinero al proveedor: el límite evita abusos y gastos inesperados. Basta para una sola instancia.
 */
@Component
public class AssistantRateLimiter {

    private static final Duration HOUR = Duration.ofHours(1);
    private static final Duration DAY = Duration.ofDays(1);

    private final AssistantProperties properties;
    private final Clock clock;
    private final Map<UUID, Deque<Instant>> calls = new ConcurrentHashMap<>();

    public AssistantRateLimiter(AssistantProperties properties, Clock clock) {
        this.properties = properties;
        this.clock = clock;
    }

    public void acquire(UUID userId) {
        Instant now = clock.instant();
        Deque<Instant> history = calls.computeIfAbsent(userId, id -> new ArrayDeque<>());
        synchronized (history) {
            while (!history.isEmpty() && !now.isBefore(history.peekFirst().plus(DAY))) {
                history.pollFirst();
            }
            if (history.size() >= properties.maxPerDay()) {
                throw tooMany(Duration.between(now, history.peekFirst().plus(DAY)));
            }
            long lastHour = history.stream().filter(at -> now.isBefore(at.plus(HOUR))).count();
            if (lastHour >= properties.maxPerHour()) {
                Instant oldestInHour = history.stream().filter(at -> now.isBefore(at.plus(HOUR))).findFirst().orElse(now);
                throw tooMany(Duration.between(now, oldestInHour.plus(HOUR)));
            }
            history.addLast(now);
        }
    }

    private static TooManyRequestsException tooMany(Duration retryAfter) {
        return new TooManyRequestsException("Llegó al límite de preguntas al asistente.", retryAfter);
    }
}
