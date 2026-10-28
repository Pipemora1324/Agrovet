package co.edu.ucc.agrovet.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

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

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nimbusds.jose.jwk.source.ImmutableSecret;

import co.edu.ucc.agrovet.IntegrationTest;

class AuthIntegrationTest extends IntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    JwtEncoder jwtEncoder;
    @Autowired
    JdbcTemplate jdbc;

    private JsonNode register(String email) throws Exception {
        String body = mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Ana\",\"email\":\"" + email + "\",\"password\":\"clave-segura-1\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(body);
    }

    private org.springframework.test.web.servlet.ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}"));
    }

    private org.springframework.test.web.servlet.ResultActions refresh(String token) throws Exception {
        return mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + token + "\"}"));
    }

    private static String unique() {
        return "u" + UUID.randomUUID().toString().substring(0, 8) + "@correo.co";
    }

    @Test
    void registerReturnsTokensAndStoresBcryptHash() throws Exception {
        String email = unique();
        JsonNode tokens = register(email);
        assertThat(tokens.get("accessToken").asText()).isNotBlank();
        assertThat(tokens.get("refreshToken").asText()).isNotBlank();
        assertThat(tokens.get("expiresIn").asLong()).isEqualTo(900);

        String hash = jdbc.queryForObject("SELECT password_hash FROM users WHERE email = ?", String.class, email);
        assertThat(hash).startsWith("$2a$12$").doesNotContain("clave-segura-1");
        String stored = jdbc.queryForObject("SELECT token_hash FROM refresh_tokens LIMIT 1", String.class);
        assertThat(stored).hasSize(64);
    }

    @Test
    void duplicateEmailIsRejected() throws Exception {
        String email = unique();
        register(email);
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Otra\",\"email\":\"" + email.toUpperCase() + "\",\"password\":\"otra-clave-1\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.detail").value("Ya existe una cuenta con ese correo."));
    }

    @Test
    void invalidRegistrationReturnsFieldErrorsInSpanish() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"email\":\"no-es-correo\",\"password\":\"corta\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.name").value("El nombre es obligatorio."))
                .andExpect(jsonPath("$.errors.email").value("El correo no es válido."))
                .andExpect(jsonPath("$.errors.password").value("La contraseña debe tener entre 8 y 72 caracteres."));
    }

    @Test
    void loginWorksAndWrongPasswordIsRejected() throws Exception {
        String email = unique();
        register(email);
        login(email, "clave-segura-1").andExpect(status().isOk()).andExpect(jsonPath("$.accessToken").isNotEmpty());
        login(email, "incorrecta").andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Correo o contraseña incorrectos."));
        login(unique(), "clave-segura-1").andExpect(status().isUnauthorized());
    }

    @Test
    void loginIsRateLimited() throws Exception {
        String email = unique();
        register(email);
        for (int i = 0; i < 5; i++) {
            login(email, "incorrecta").andExpect(status().isUnauthorized());
        }
        login(email, "clave-segura-1")
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    void accessTokenOpensProtectedEndpoint() throws Exception {
        String email = unique();
        String access = register(email).get("accessToken").asText();
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value(email));
    }

    @Test
    void refreshRotatesAndReuseRevokesFamily() throws Exception {
        String first = register(unique()).get("refreshToken").asText();

        String body = refresh(first).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String second = json.readTree(body).get("refreshToken").asText();
        assertThat(second).isNotEqualTo(first);

        // Reutilizar el primero (ya rotado) se trata como robo: falla y revoca también el segundo
        refresh(first).andExpect(status().isUnauthorized());
        refresh(second).andExpect(status().isUnauthorized());
    }

    @Test
    void logoutRevokesRefreshToken() throws Exception {
        String token = register(unique()).get("refreshToken").asText();
        mvc.perform(post("/api/auth/logout").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + token + "\"}"))
                .andExpect(status().isNoContent());
        refresh(token).andExpect(status().isUnauthorized());
    }

    @Test
    void protectedEndpointRequiresValidToken() throws Exception {
        mvc.perform(get("/api/auth/me")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer basura")).andExpect(status().isUnauthorized());
    }

    @Test
    void expiredTokenIsRejected() throws Exception {
        String userId = register(unique()).get("user").get("id").asText();
        Instant past = Instant.now().minusSeconds(3600);
        String expired = jwtEncoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(),
                JwtClaimsSet.builder().issuer("agrovet").subject(userId).issuedAt(past.minusSeconds(900))
                        .expiresAt(past).build())).getTokenValue();
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void tokenSignedWithOtherKeyIsRejected() throws Exception {
        String userId = register(unique()).get("user").get("id").asText();
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
