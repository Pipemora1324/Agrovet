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
}
