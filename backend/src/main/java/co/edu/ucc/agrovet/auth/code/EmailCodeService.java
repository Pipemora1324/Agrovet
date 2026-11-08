package co.edu.ucc.agrovet.auth.code;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;

import javax.crypto.Mac;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Códigos de 6 dígitos enviados por correo.
 * <ul>
 * <li>Se guarda el HMAC-SHA256 del código con una clave del servidor. Un hash simple no basta: solo
 * hay un millón de códigos posibles y se probarían todos en segundos si se filtrara la base.</li>
 * <li>El HMAC incluye el usuario y el propósito, así un código no sirve para otra cuenta ni para otra
 * acción.</li>
 * <li>Emitir uno nuevo anula los anteriores; cada código admite {@code maxAttempts} intentos y vence
 * en {@code ttl}.</li>
 * </ul>
 */
@Service
public class EmailCodeService {

    private static final String HMAC = "HmacSHA256";

    private final EmailCodeRepository codes;
    private final EmailCodeProperties properties;
    private final Clock clock;
    private final SecretKey codeKey;
    private final SecureRandom random = new SecureRandom();

    public EmailCodeService(EmailCodeRepository codes, EmailCodeProperties properties, Clock clock,
            SecretKey jwtSecretKey) {
        this.codes = codes;
        this.properties = properties;
        this.clock = clock;
        // Clave propia derivada del secreto del servidor: un HMAC de los códigos no sirve para firmar JWT
        this.codeKey = new SecretKeySpec(hmac(jwtSecretKey, "agrovet-email-code-v1"), HMAC);
    }

    public Duration ttl() {
        return properties.ttl();
    }

    /** true si todavía se puede emitir un código hoy para esa cuenta y propósito. */
    @Transactional(readOnly = true)
    public boolean canIssue(UUID userId, CodePurpose purpose) {
        Instant since = clock.instant().minus(Duration.ofDays(1));
        return codes.countByUserIdAndPurposeAndCreatedAtAfter(userId, purpose, since) < properties.maxPerDay();
    }

    /** Hay un código vigente que el usuario todavía puede usar. */
    @Transactional(readOnly = true)
    public boolean hasActiveCode(UUID userId, CodePurpose purpose) {
        Instant now = clock.instant();
        return codes.findFirstByUserIdAndPurposeAndConsumedAtIsNullOrderByCreatedAtDesc(userId, purpose)
                .filter(code -> code.isActive(now))
                .isPresent();
    }

    /** Crea un código nuevo (anulando los anteriores) y devuelve el valor para enviarlo por correo. */
    @Transactional(propagation = Propagation.MANDATORY)
    public String issue(UUID userId, CodePurpose purpose) {
        Instant now = clock.instant();
        codes.consumeAll(userId, purpose, now);
        String value = "%06d".formatted(random.nextInt(1_000_000));
        codes.save(new EmailCode(userId, purpose, hash(userId, purpose, value), now, now.plus(properties.ttl())));
        return value;
    }

    /**
     * Comprueba el código. Un fallo cuenta como intento (y se guarda aunque quien llama luego lance una
     * excepción, siempre que su transacción no haga rollback por ella).
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean verify(UUID userId, CodePurpose purpose, String value) {
        Instant now = clock.instant();
        Optional<EmailCode> current = codes
                .findFirstByUserIdAndPurposeAndConsumedAtIsNullOrderByCreatedAtDesc(userId, purpose)
                .filter(code -> code.isActive(now));
        if (current.isEmpty()) {
            return false;
        }
        EmailCode code = current.get();
        byte[] expected = code.getCodeHash().getBytes(StandardCharsets.US_ASCII);
        byte[] given = hash(userId, purpose, value == null ? "" : value).getBytes(StandardCharsets.US_ASCII);
        if (!MessageDigest.isEqual(expected, given)) {
            code.registerFailedAttempt(properties.maxAttempts(), now);
            return false;
        }
        code.consume(now);
        return true;
    }

    String hash(UUID userId, CodePurpose purpose, String value) {
        return HexFormat.of().formatHex(hmac(codeKey, userId + ":" + purpose + ":" + value));
    }

    private static byte[] hmac(SecretKey key, String data) {
        try {
            Mac mac = Mac.getInstance(HMAC);
            mac.init(key);
            return mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HMAC-SHA256 no disponible", e);
        }
    }
}
