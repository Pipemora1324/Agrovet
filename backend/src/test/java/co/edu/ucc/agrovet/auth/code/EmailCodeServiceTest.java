package co.edu.ucc.agrovet.auth.code;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class EmailCodeServiceTest {

    private static final Instant NOW = Instant.parse("2026-11-01T12:00:00Z");
    private static final Duration TTL = Duration.ofMinutes(15);
    private static final UUID USER = UUID.randomUUID();

    private final EmailCodeRepository codes = mock(EmailCodeRepository.class);
    private final EmailCodeProperties properties = new EmailCodeProperties(TTL, 3, Duration.ofSeconds(60), 10, 5,
            Duration.ofHours(1));
    private final EmailCodeService service = new EmailCodeService(codes, properties,
            Clock.fixed(NOW, ZoneOffset.UTC), key("secreto-del-servidor-de-32-bytes!!"));

    private static SecretKey key(String secret) {
        return new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }

    private EmailCode stored(String value, Instant createdAt) {
        return new EmailCode(USER, CodePurpose.VERIFY_EMAIL, service.hash(USER, CodePurpose.VERIFY_EMAIL, value),
                createdAt, createdAt.plus(TTL));
    }

    private void current(EmailCode code) {
        when(codes.findFirstByUserIdAndPurposeAndConsumedAtIsNullOrderByCreatedAtDesc(USER, CodePurpose.VERIFY_EMAIL))
                .thenReturn(Optional.ofNullable(code));
    }

    @Test
    void ttlComesFromProperties() {
        assertThat(service.ttl()).isEqualTo(TTL);
    }

    @Test
    void issueVoidsPreviousCodesAndStoresOnlyTheHmac() {
        String value = service.issue(USER, CodePurpose.VERIFY_EMAIL);

        assertThat(value).matches("\\d{6}");
        verify(codes).consumeAll(USER, CodePurpose.VERIFY_EMAIL, NOW);
        ArgumentCaptor<EmailCode> saved = ArgumentCaptor.forClass(EmailCode.class);
        verify(codes).save(saved.capture());
        EmailCode code = saved.getValue();
        assertThat(code.getUserId()).isEqualTo(USER);
        assertThat(code.getPurpose()).isEqualTo(CodePurpose.VERIFY_EMAIL);
        assertThat(code.getCodeHash()).isEqualTo(service.hash(USER, CodePurpose.VERIFY_EMAIL, value))
                .doesNotContain(value).hasSize(64);
        assertThat(code.getCreatedAt()).isEqualTo(NOW);
        assertThat(code.isActive(NOW.plus(TTL).minusSeconds(1))).isTrue();
        assertThat(code.isActive(NOW.plus(TTL))).isFalse();
    }

    @Test
    void hashDependsOnUserPurposeValueAndServerKey() {
        String base = service.hash(USER, CodePurpose.VERIFY_EMAIL, "123456");
        assertThat(service.hash(USER, CodePurpose.VERIFY_EMAIL, "123456")).isEqualTo(base);
        assertThat(service.hash(UUID.randomUUID(), CodePurpose.VERIFY_EMAIL, "123456")).isNotEqualTo(base);
        assertThat(service.hash(USER, CodePurpose.RESET_PASSWORD, "123456")).isNotEqualTo(base);
        assertThat(service.hash(USER, CodePurpose.VERIFY_EMAIL, "123457")).isNotEqualTo(base);
        EmailCodeService otherServer = new EmailCodeService(codes, properties, Clock.fixed(NOW, ZoneOffset.UTC),
                key("otro-secreto-distinto-de-32-bytes!!"));
        assertThat(otherServer.hash(USER, CodePurpose.VERIFY_EMAIL, "123456")).isNotEqualTo(base);
    }

    @Test
    void rightCodeIsAcceptedOnce() {
        EmailCode code = stored("123456", NOW.minusSeconds(30));
        current(code);

        assertThat(service.verify(USER, CodePurpose.VERIFY_EMAIL, "123456")).isTrue();
        assertThat(code.isActive(NOW)).isFalse();
        assertThat(code.getAttempts()).isZero();
    }

    @Test
    void wrongCodeCountsAnAttemptUntilTheLimit() {
        EmailCode code = stored("123456", NOW.minusSeconds(30));
        current(code);

        assertThat(service.verify(USER, CodePurpose.VERIFY_EMAIL, "000000")).isFalse();
        assertThat(code.getAttempts()).isEqualTo(1);
        assertThat(code.isActive(NOW)).isTrue();
        assertThat(service.verify(USER, CodePurpose.VERIFY_EMAIL, null)).isFalse();
        assertThat(code.isActive(NOW)).isTrue();
        // El tercer fallo agota el código: ni el valor correcto sirve después
        assertThat(service.verify(USER, CodePurpose.VERIFY_EMAIL, "111111")).isFalse();
        assertThat(code.getAttempts()).isEqualTo(3);
        assertThat(code.isActive(NOW)).isFalse();
    }

    @Test
    void missingValueNeverMatchesNotEvenTheTextNull() {
        current(stored("null", NOW.minusSeconds(30)));

        assertThat(service.verify(USER, CodePurpose.VERIFY_EMAIL, null)).isFalse();
    }

    @Test
    void expiredOrMissingCodeIsRefused() {
        EmailCode expired = stored("123456", NOW.minus(TTL));
        current(expired);
        assertThat(service.verify(USER, CodePurpose.VERIFY_EMAIL, "123456")).isFalse();
        assertThat(expired.getAttempts()).isZero();
        assertThat(service.hasActiveCode(USER, CodePurpose.VERIFY_EMAIL)).isFalse();

        current(null);
        assertThat(service.verify(USER, CodePurpose.VERIFY_EMAIL, "123456")).isFalse();
        assertThat(service.hasActiveCode(USER, CodePurpose.VERIFY_EMAIL)).isFalse();
        verify(codes, never()).save(any());
    }

    @Test
    void activeCodeIsReported() {
        current(stored("123456", NOW.minusSeconds(30)));
        assertThat(service.hasActiveCode(USER, CodePurpose.VERIFY_EMAIL)).isTrue();
    }

    @Test
    void dailyLimitCountsCodesOfTheLast24Hours() {
        Instant since = NOW.minus(Duration.ofDays(1));
        when(codes.countByUserIdAndPurposeAndCreatedAtAfter(USER, CodePurpose.RESET_PASSWORD, since))
                .thenReturn(9L, 10L);

        assertThat(service.canIssue(USER, CodePurpose.RESET_PASSWORD)).isTrue();
        assertThat(service.canIssue(USER, CodePurpose.RESET_PASSWORD)).isFalse();
    }
}
