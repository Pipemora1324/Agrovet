package co.edu.ucc.agrovet.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class LoginRateLimiterTest {

    private final MutableClock clock = new MutableClock(Instant.parse("2026-01-01T10:00:00Z"));
    private LoginRateLimiter limiter;

    @BeforeEach
    void setUp() {
        limiter = new LoginRateLimiter(new LoginRateLimitProperties(3, Duration.ofMinutes(5), 5), clock);
    }

    @Test
    void blocksAfterMaxAttemptsForSameIpAndEmail() {
        for (int i = 0; i < 3; i++) {
            limiter.registerAttempt("1.1.1.1", "ana@correo.co");
        }
        assertThatThrownBy(() -> limiter.registerAttempt("1.1.1.1", "ana@correo.co"))
                .isInstanceOf(TooManyLoginAttemptsException.class)
                .satisfies(ex -> assertThat(((TooManyLoginAttemptsException) ex).getRetryAfter())
                        .isEqualTo(Duration.ofMinutes(5)));
    }

    @Test
    void emailComparisonIgnoresCase() {
        for (int i = 0; i < 3; i++) {
            limiter.registerAttempt("1.1.1.1", "Ana@Correo.co");
        }
        assertThatThrownBy(() -> limiter.registerAttempt("1.1.1.1", "ana@correo.co"))
                .isInstanceOf(TooManyLoginAttemptsException.class);
    }

    @Test
    void allowsAgainAfterWindow() {
        for (int i = 0; i < 3; i++) {
            limiter.registerAttempt("1.1.1.1", "ana@correo.co");
        }
        clock.advance(Duration.ofMinutes(5));
        assertThatCode(() -> limiter.registerAttempt("1.1.1.1", "ana@correo.co")).doesNotThrowAnyException();
    }

    @Test
    void resetClearsPairCounter() {
        for (int i = 0; i < 3; i++) {
            limiter.registerAttempt("1.1.1.1", "ana@correo.co");
        }
        limiter.reset("1.1.1.1", "ana@correo.co");
        assertThatCode(() -> limiter.registerAttempt("1.1.1.1", "ana@correo.co")).doesNotThrowAnyException();
    }

    @Test
    void blocksIpThatTriesManyEmails() {
        for (int i = 0; i < 5; i++) {
            limiter.registerAttempt("2.2.2.2", "usuario" + i + "@correo.co");
        }
        assertThatThrownBy(() -> limiter.registerAttempt("2.2.2.2", "otro@correo.co"))
                .isInstanceOf(TooManyLoginAttemptsException.class);
        assertThatCode(() -> limiter.registerAttempt("3.3.3.3", "otro@correo.co")).doesNotThrowAnyException();
    }

    @Test
    void expiredCountersAreDroppedOnlyAfterTheThreshold() {
        // Cada intento con IP y correo nuevos guarda dos contadores: el de la pareja y el de la IP
        for (int i = 0; i < 5_000; i++) {
            limiter.registerAttempt("10.0." + (i / 250) + "." + (i % 250), "u" + i + "@correo.co");
        }
        assertThat(limiter.trackedKeys()).isEqualTo(10_000);
        clock.advance(Duration.ofMinutes(5));

        // Justo en el umbral todavía no se limpia
        limiter.registerAttempt("20.0.0.1", "a@correo.co");
        assertThat(limiter.trackedKeys()).isEqualTo(10_002);

        // Por encima se borran los vencidos y quedan los vigentes
        limiter.registerAttempt("20.0.0.2", "b@correo.co");
        assertThat(limiter.trackedKeys()).isEqualTo(4);
        for (int i = 0; i < 2; i++) {
            limiter.registerAttempt("20.0.0.1", "a@correo.co");
        }
        assertThatThrownBy(() -> limiter.registerAttempt("20.0.0.1", "a@correo.co"))
                .isInstanceOf(TooManyLoginAttemptsException.class);
    }

    static final class MutableClock extends Clock {
        private Instant now;

        MutableClock(Instant now) {
            this.now = now;
        }

        void advance(Duration duration) {
            now = now.plus(duration);
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}
