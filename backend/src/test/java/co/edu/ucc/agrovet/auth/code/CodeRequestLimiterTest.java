package co.edu.ucc.agrovet.auth.code;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;

import org.junit.jupiter.api.Test;

import co.edu.ucc.agrovet.MutableClock;
import co.edu.ucc.agrovet.common.TooManyRequestsException;

class CodeRequestLimiterTest {

    private final MutableClock clock = new MutableClock();
    private final EmailCodeProperties properties = new EmailCodeProperties(Duration.ofMinutes(15), 5,
            Duration.ofSeconds(60), 10, 3, Duration.ofHours(1));
    private final CodeRequestLimiter limiter = new CodeRequestLimiter(properties, clock);

    @Test
    void sameEmailMustWaitForCooldownEvenIfAccountDoesNotExist() {
        limiter.acquire("1.1.1.1", "nadie@correo.co", CodePurpose.VERIFY_EMAIL);
        assertThatThrownBy(() -> limiter.acquire("1.1.1.1", "NADIE@correo.co", CodePurpose.VERIFY_EMAIL))
                .isInstanceOf(TooManyRequestsException.class)
                .satisfies(e -> assertThat(((TooManyRequestsException) e).getRetryAfter())
                        .isEqualTo(Duration.ofSeconds(60)));

        clock.advance(Duration.ofSeconds(60));
        limiter.acquire("1.1.1.1", "nadie@correo.co", CodePurpose.VERIFY_EMAIL);
    }

    @Test
    void cooldownIsSeparatePerPurpose() {
        limiter.acquire("1.1.1.1", "ana@correo.co", CodePurpose.VERIFY_EMAIL);
        limiter.acquire("1.1.1.1", "ana@correo.co", CodePurpose.RESET_PASSWORD);
    }

    @Test
    void ipLimitAppliesAcrossEmails() {
        for (int i = 0; i < 3; i++) {
            limiter.acquire("2.2.2.2", "c" + i + "@correo.co", CodePurpose.VERIFY_EMAIL);
        }
        assertThatThrownBy(() -> limiter.acquire("2.2.2.2", "otro@correo.co", CodePurpose.VERIFY_EMAIL))
                .isInstanceOf(TooManyRequestsException.class);
        assertThat(limiter.tryAcquire("2.2.2.2", "otro@correo.co", CodePurpose.VERIFY_EMAIL)).isFalse();
        limiter.acquire("3.3.3.3", "otro@correo.co", CodePurpose.VERIFY_EMAIL);

        clock.advance(Duration.ofHours(1));
        limiter.acquire("2.2.2.2", "nuevo@correo.co", CodePurpose.VERIFY_EMAIL);
    }

    @Test
    void tryAcquireReportsSuccess() {
        assertThat(limiter.tryAcquire("4.4.4.4", "ana@correo.co", CodePurpose.VERIFY_EMAIL)).isTrue();
        assertThat(limiter.tryAcquire("4.4.4.4", "ana@correo.co", CodePurpose.VERIFY_EMAIL)).isFalse();
    }

    @Test
    void expiredEntriesAreDroppedOnlyAfterTheThreshold() {
        for (int i = 0; i < 10_000; i++) {
            limiter.acquire("10.0." + (i / 250) + "." + (i % 250), "u" + i + "@correo.co", CodePurpose.VERIFY_EMAIL);
        }
        assertThat(limiter.trackedEmails()).isEqualTo(10_000);
        assertThat(limiter.trackedIps()).isEqualTo(10_000);
        clock.advance(Duration.ofHours(1));

        // Justo en el umbral todavía no se limpia
        limiter.acquire("20.0.0.1", "a@correo.co", CodePurpose.VERIFY_EMAIL);
        assertThat(limiter.trackedEmails()).isEqualTo(10_001);
        assertThat(limiter.trackedIps()).isEqualTo(10_001);

        // Por encima se borran los vencidos; el último correo sigue en espera
        limiter.acquire("20.0.0.2", "b@correo.co", CodePurpose.VERIFY_EMAIL);
        assertThat(limiter.trackedEmails()).isEqualTo(2);
        assertThat(limiter.trackedIps()).isEqualTo(2);
        assertThatThrownBy(() -> limiter.acquire("20.0.0.3", "a@correo.co", CodePurpose.VERIFY_EMAIL))
                .isInstanceOf(TooManyRequestsException.class);
    }

    @Test
    void cooldownExpiredEntriesAreDroppedEvenInsideTheIpWindow() {
        for (int i = 0; i < 10_001; i++) {
            limiter.acquire("10.1." + (i / 250) + "." + (i % 250), "u" + i + "@correo.co", CodePurpose.VERIFY_EMAIL);
        }
        // Pasó la espera entre envíos pero no la ventana por IP: se limpian solo los correos
        clock.advance(Duration.ofSeconds(60));
        limiter.acquire("20.0.0.9", "z@correo.co", CodePurpose.VERIFY_EMAIL);
        assertThat(limiter.trackedEmails()).isEqualTo(1);
        assertThat(limiter.trackedIps()).isEqualTo(10_002);
    }
}
