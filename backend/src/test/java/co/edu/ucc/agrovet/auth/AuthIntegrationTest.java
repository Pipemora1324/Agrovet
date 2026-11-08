package co.edu.ucc.agrovet.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nimbusds.jose.jwk.source.ImmutableSecret;

import co.edu.ucc.agrovet.IntegrationTest;
import co.edu.ucc.agrovet.MutableClock;
import co.edu.ucc.agrovet.RecordingEmailSender;
import co.edu.ucc.agrovet.TestUsers;
import co.edu.ucc.agrovet.TestUsers.TestUser;

class AuthIntegrationTest extends IntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    JwtEncoder jwtEncoder;
    @Autowired
    JdbcTemplate jdbc;
    @Autowired
    RecordingEmailSender mail;
    @Autowired
    MutableClock clock;

    private ResultActions postJson(String path, String body) throws Exception {
        return mvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions register(String email, String password) throws Exception {
        return postJson("/api/auth/register", TestUsers.registerBody("Ana", email, password));
    }

    private ResultActions verify(String email, String code) throws Exception {
        return postJson("/api/auth/verify-email", "{\"email\":\"" + email + "\",\"code\":\"" + code + "\"}");
    }

    private ResultActions login(String email, String password) throws Exception {
        return postJson("/api/auth/login", "{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}");
    }

    private ResultActions refresh(String token) throws Exception {
        return postJson("/api/auth/refresh", "{\"refreshToken\":\"" + token + "\"}");
    }

    private ResultActions emailOnly(String path, String email) throws Exception {
        return postJson(path, "{\"email\":\"" + email + "\"}");
    }

    private static String wrong(String code) {
        return code.equals("000000") ? "111111" : "000000";
    }

    // ---- Registro y verificación ----

    @Test
    void registerCreatesUnverifiedAccountAndEmailsCodeStoredOnlyAsHmac() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD).andExpect(status().isAccepted())
                .andExpect(jsonPath("$.message").value(AuthService.CODE_SENT))
                .andExpect(jsonPath("$.accessToken").doesNotExist());

        assertThat(jdbc.queryForObject("SELECT email_verified FROM users WHERE email = ?", Boolean.class, email))
                .isFalse();
        String code = mail.lastCode(email);
        String stored = jdbc.queryForObject("SELECT c.code_hash FROM email_codes c JOIN users u ON u.id = c.user_id "
                + "WHERE u.email = ?", String.class, email);
        assertThat(stored).hasSize(64).matches("[0-9a-f]+").doesNotContain(code);
        assertThat(mail.sentTo(email).getLast().body()).contains("Vence en 15 minutos");
    }

    @Test
    void loginIsRefusedUntilEmailIsVerified() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD);
        login(email, TestUsers.PASSWORD).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"))
                .andExpect(jsonPath("$.accessToken").doesNotExist());

        verify(email, mail.lastCode(email)).andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.expiresIn").value(900));
        login(email, TestUsers.PASSWORD).andExpect(status().isOk());

        String hash = jdbc.queryForObject("SELECT password_hash FROM users WHERE email = ?", String.class, email);
        assertThat(hash).startsWith("$2a$12$").doesNotContain(TestUsers.PASSWORD);
    }

    @Test
    void wrongPasswordOnUnverifiedAccountLooksLikeAnyOtherFailure() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD);
        login(email, "incorrecta").andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Correo o contraseña incorrectos."));
    }

    @Test
    void codeAllowsFiveAttemptsThenStopsWorking() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD);
        String code = mail.lastCode(email);
        for (int i = 0; i < 5; i++) {
            verify(email, wrong(code)).andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.detail").value(new InvalidCodeException().getMessage()));
        }
        verify(email, code).andExpect(status().isBadRequest());
        assertThat(jdbc.queryForObject("SELECT attempts FROM email_codes c JOIN users u ON u.id = c.user_id "
                + "WHERE u.email = ?", Integer.class, email)).isEqualTo(5);
    }

    @Test
    void codeExpiresAfterFifteenMinutes() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD);
        String code = mail.lastCode(email);
        clock.advance(Duration.ofMinutes(15).plusSeconds(1));
        verify(email, code).andExpect(status().isBadRequest());
    }

    @Test
    void resendWaitsForCooldownAndReplacesPreviousCode() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD);
        String first = mail.lastCode(email);

        emailOnly("/api/auth/resend-code", email).andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));

        clock.advance(Duration.ofSeconds(61));
        emailOnly("/api/auth/resend-code", email).andExpect(status().isAccepted());
        String second = mail.lastCode(email);
        assertThat(mail.sentTo(email)).hasSize(2);

        if (!first.equals(second)) {
            verify(email, first).andExpect(status().isBadRequest());
        }
        verify(email, second).andExpect(status().isOk());
    }

    @Test
    void loginOfUnverifiedAccountSendsNewCodeWhenNoneIsActive() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD);
        clock.advance(Duration.ofMinutes(16));

        login(email, TestUsers.PASSWORD).andExpect(status().isForbidden());
        assertThat(mail.sentTo(email)).hasSize(2);
        verify(email, mail.lastCode(email)).andExpect(status().isOk());
    }

    @Test
    void responsesDoNotRevealWhetherEmailExists() throws Exception {
        TestUser owner = TestUsers.register(mvc, json, mail);
        String unknown = TestUsers.uniqueEmail();
        clock.advance(Duration.ofSeconds(61));

        // Registrar un correo ya verificado responde igual y solo avisa al dueño
        String existing = register(owner.email(), "otra-clave-99").andExpect(status().isAccepted())
                .andReturn().getResponse().getContentAsString();
        String fresh = register(unknown, "otra-clave-99").andExpect(status().isAccepted())
                .andReturn().getResponse().getContentAsString();
        assertThat(existing).isEqualTo(fresh);
        assertThat(mail.sentTo(owner.email()).getLast().subject()).contains("intento de registro");
        login(owner.email(), TestUsers.PASSWORD).andExpect(status().isOk());

        String noAccount = TestUsers.uniqueEmail();
        emailOnly("/api/auth/resend-code", noAccount).andExpect(status().isAccepted())
                .andExpect(jsonPath("$.message").value(AuthService.CODE_SENT));
        emailOnly("/api/auth/password/forgot", noAccount).andExpect(status().isAccepted())
                .andExpect(jsonPath("$.message").value(AuthService.CODE_SENT));
        verify(noAccount, "123456").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value(new InvalidCodeException().getMessage()));
        assertThat(mail.sentTo(noAccount)).isEmpty();
    }

    @Test
    void registeringAgainBeforeVerifyingReplacesThePassword() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, "clave-del-intruso");
        clock.advance(Duration.ofSeconds(61));
        register(email, TestUsers.PASSWORD).andExpect(status().isAccepted());

        verify(email, mail.lastCode(email)).andExpect(status().isOk());
        login(email, "clave-del-intruso").andExpect(status().isUnauthorized());
        login(email, TestUsers.PASSWORD).andExpect(status().isOk());
    }

    @Test
    void verifiedAccountCannotBeVerifiedAgain() throws Exception {
        TestUser user = TestUsers.register(mvc, json, mail);
        verify(user.email(), mail.lastCode(user.email())).andExpect(status().isBadRequest());
    }

    @Test
    void invalidRegistrationReturnsFieldErrorsInSpanish() throws Exception {
        postJson("/api/auth/register", "{\"name\":\"\",\"email\":\"no-es-correo\",\"password\":\"corta\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.name").value("El nombre es obligatorio."))
                .andExpect(jsonPath("$.errors.email").value("El correo no es válido."))
                .andExpect(jsonPath("$.errors.password").value("La contraseña debe tener entre 8 y 72 caracteres."));
        verify("a@correo.co", "12ab").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.code").value("El código tiene 6 números."));
    }

    // ---- Recuperación de contraseña ----

    @Test
    void passwordResetWithCodeChangesPasswordAndClosesSessions() throws Exception {
        TestUser user = TestUsers.register(mvc, json, mail);
        emailOnly("/api/auth/password/forgot", user.email()).andExpect(status().isAccepted());
        String code = mail.lastCode(user.email());
        assertThat(mail.sentTo(user.email()).getLast().subject()).contains("contraseña");

        postJson("/api/auth/password/reset", "{\"email\":\"" + user.email() + "\",\"code\":\"" + code
                + "\",\"newPassword\":\"nueva-clave-22\"}").andExpect(status().isNoContent());

        refresh(user.refreshToken()).andExpect(status().isUnauthorized());
        login(user.email(), TestUsers.PASSWORD).andExpect(status().isUnauthorized());
        login(user.email(), "nueva-clave-22").andExpect(status().isOk());
    }

    @Test
    void codesOnlyWorkForTheirPurpose() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD);
        String verifyCode = mail.lastCode(email);
        postJson("/api/auth/password/reset", "{\"email\":\"" + email + "\",\"code\":\"" + verifyCode
                + "\",\"newPassword\":\"nueva-clave-22\"}").andExpect(status().isBadRequest());
        verify(email, verifyCode).andExpect(status().isOk());
    }

    @Test
    void passwordResetAlsoVerifiesTheEmail() throws Exception {
        String email = TestUsers.uniqueEmail();
        register(email, TestUsers.PASSWORD);
        emailOnly("/api/auth/password/forgot", email).andExpect(status().isAccepted());
        postJson("/api/auth/password/reset", "{\"email\":\"" + email + "\",\"code\":\"" + mail.lastCode(email)
                + "\",\"newPassword\":\"nueva-clave-22\"}").andExpect(status().isNoContent());
        login(email, "nueva-clave-22").andExpect(status().isOk());
    }

    // ---- Sesión ----

    @Test
    void loginIsRateLimited() throws Exception {
        TestUser user = TestUsers.register(mvc, json, mail);
        for (int i = 0; i < 5; i++) {
            login(user.email(), "incorrecta").andExpect(status().isUnauthorized());
        }
        login(user.email(), TestUsers.PASSWORD)
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    void accessTokenOpensProtectedEndpoint() throws Exception {
        TestUser user = TestUsers.register(mvc, json, mail);
        mvc.perform(get("/api/auth/me").header("Authorization", user.bearer()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value(user.email()));
    }

    @Test
    void refreshRotatesAndReuseRevokesFamily() throws Exception {
        String first = TestUsers.register(mvc, json, mail).refreshToken();

        String body = refresh(first).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String second = json.readTree(body).get("refreshToken").asText();
        assertThat(second).isNotEqualTo(first);
        assertThat(jdbc.queryForObject("SELECT token_hash FROM refresh_tokens LIMIT 1", String.class)).hasSize(64);

        // Reutilizar el primero (ya rotado) se trata como robo: falla y revoca también el segundo
        refresh(first).andExpect(status().isUnauthorized());
        refresh(second).andExpect(status().isUnauthorized());
    }

    @Test
    void logoutRevokesRefreshToken() throws Exception {
        String token = TestUsers.register(mvc, json, mail).refreshToken();
        postJson("/api/auth/logout", "{\"refreshToken\":\"" + token + "\"}").andExpect(status().isNoContent());
        refresh(token).andExpect(status().isUnauthorized());
    }

    @Test
    void protectedEndpointRequiresValidToken() throws Exception {
        mvc.perform(get("/api/auth/me")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer basura")).andExpect(status().isUnauthorized());
    }

    @Test
    void expiredTokenIsRejected() throws Exception {
        String userId = TestUsers.register(mvc, json, mail).id().toString();
        Instant past = Instant.now().minusSeconds(3600);
        String expired = jwtEncoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(),
                JwtClaimsSet.builder().issuer("agrovet").subject(userId).issuedAt(past.minusSeconds(900))
                        .expiresAt(past).build())).getTokenValue();
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void tokenSignedWithOtherKeyIsRejected() throws Exception {
        String userId = TestUsers.register(mvc, json, mail).id().toString();
        byte[] otherKey = Base64.getDecoder().decode("b3RyYS1jbGF2ZS1kZS1hdGFjYW50ZS0wMTIzNDU2Nzg5YWJjZGVm");
        JwtEncoder forger = new NimbusJwtEncoder(new ImmutableSecret<>(new SecretKeySpec(otherKey, "HmacSHA256")));
        String forged = forger.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(),
                JwtClaimsSet.builder().issuer("agrovet").subject(userId).issuedAt(Instant.now())
                        .expiresAt(Instant.now().plusSeconds(600)).build())).getTokenValue();
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + forged))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void corsAllowsOnlyConfiguredOrigins() throws Exception {
        mvc.perform(options("/api/auth/login").header("Origin", "http://localhost:3000")
                        .header("Access-Control-Request-Method", "POST"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:3000"));
        mvc.perform(options("/api/auth/login").header("Origin", "https://sitio-malicioso.com")
                        .header("Access-Control-Request-Method", "POST"))
                .andExpect(status().isForbidden());
    }

    @Test
    void swaggerIsAvailable() throws Exception {
        mvc.perform(get("/v3/api-docs")).andExpect(status().isOk())
                .andExpect(jsonPath("$.info.title").value("AgroVet API"));
    }
}
