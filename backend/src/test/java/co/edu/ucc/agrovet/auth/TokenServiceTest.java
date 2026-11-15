package co.edu.ucc.agrovet.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.Set;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

import com.nimbusds.jose.jwk.source.ImmutableSecret;

import co.edu.ucc.agrovet.config.JwtProperties;
import co.edu.ucc.agrovet.user.User;

class TokenServiceTest {

    private final SecretKey key = new SecretKeySpec(
            "clave-de-prueba-de-al-menos-32-bytes".getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    private final JwtProperties properties = new JwtProperties("x", "agrovet-test", Duration.ofMinutes(15),
            Duration.ofDays(14));
    private final TokenService service = new TokenService(new NimbusJwtEncoder(new ImmutableSecret<>(key)),
            properties);

    @Test
    void accessTokenIsShortLivedHs256WithUserAsSubject() {
        // El decodificador valida la fecha de vencimiento: se emite con la hora actual
        Instant now = Instant.now().minusSeconds(5).truncatedTo(ChronoUnit.SECONDS);
        User user = new User("Ana", "ana@correo.co", "hash", now);

        String token = service.createAccessToken(user, now);

        Jwt jwt = NimbusJwtDecoder.withSecretKey(key).macAlgorithm(MacAlgorithm.HS256).build().decode(token);
        assertThat(jwt.getHeaders()).containsEntry("alg", "HS256");
        assertThat(jwt.getSubject()).isEqualTo(user.getId().toString());
        assertThat(jwt.getClaimAsString("iss")).isEqualTo("agrovet-test");
        assertThat(jwt.getIssuedAt()).isEqualTo(now);
        assertThat(jwt.getExpiresAt()).isEqualTo(now.plus(Duration.ofMinutes(15)));
        assertThat(jwt.getId()).isNotBlank();
        assertThat(service.createAccessToken(user, now)).isNotEqualTo(token);
    }

    @Test
    void accessTtlIsReportedInSeconds() {
        assertThat(service.accessTtlSeconds()).isEqualTo(900);
    }

    @Test
    void refreshTokenValuesAreRandomUrlSafeAnd256Bits() {
        Set<String> values = new HashSet<>();
        for (int i = 0; i < 50; i++) {
            String value = service.newRefreshTokenValue();
            // 32 bytes en Base64 URL sin relleno = 43 caracteres
            assertThat(value).hasSize(43).matches("[A-Za-z0-9_-]+");
            values.add(value);
        }
        assertThat(values).hasSize(50);
    }

    @Test
    void hashIsSha256HexOfTheValue() {
        assertThat(TokenService.hash("")).isEqualTo(
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
        assertThat(TokenService.hash("ñ")).hasSize(64).isNotEqualTo(TokenService.hash("n"));
    }
}
