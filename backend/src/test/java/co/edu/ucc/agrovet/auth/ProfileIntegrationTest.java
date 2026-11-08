package co.edu.ucc.agrovet.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import com.fasterxml.jackson.databind.ObjectMapper;

import co.edu.ucc.agrovet.IntegrationTest;
import co.edu.ucc.agrovet.RecordingEmailSender;
import co.edu.ucc.agrovet.TestUsers;
import co.edu.ucc.agrovet.TestUsers.TestUser;

class ProfileIntegrationTest extends IntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    JdbcTemplate jdbc;
    @Autowired
    RecordingEmailSender mail;

    private TestUser ana;
    private TestUser beto;

    @BeforeEach
    void setUp() throws Exception {
        ana = TestUsers.register(mvc, json, mail);
        beto = TestUsers.register(mvc, json, mail);
    }

    private ResultActions send(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,
            TestUser user, String body) throws Exception {
        return mvc.perform(request.header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(body));
    }

    /** Vaca con un registro, una evaluación y una alerta, subidas por la sincronización. */
    private UUID seedData(TestUser user) throws Exception {
        UUID cow = UUID.randomUUID();
        UUID record = UUID.randomUUID();
        UUID inference = UUID.randomUUID();
        UUID alert = UUID.randomUUID();
        String now = Instant.now().toString();
        send(post("/api/sync"), user, """
                {"cows":[{"id":"%s","tag":"A-1","productionStatus":"LACTATING","updatedAt":"%s","deleted":false}],
                 "dailyRecords":[{"id":"%s","cowId":"%s","recordDate":"2026-11-01","temperatureC":38.6,
                   "updatedAt":"%s","deleted":false}],
                 "inferences":[{"id":"%s","cowId":"%s","windowEndDate":"2026-11-01","probability":0.9,
                   "riskLevel":"RED","modelVersion":"v1","updatedAt":"%s","deleted":false}],
                 "alerts":[{"id":"%s","cowId":"%s","inferenceId":"%s","riskLevel":"RED","attended":false,
                   "updatedAt":"%s","deleted":false}]}
                """.formatted(cow, now, record, cow, now, inference, cow, now, alert, cow, inference, now))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rejected").isEmpty());
        return cow;
    }

    private int count(String sql, Object... args) {
        return jdbc.queryForObject(sql, Integer.class, args);
    }

    @Test
    void registrationStoresPrivacyConsent() throws Exception {
        mvc.perform(get("/api/auth/me").header("Authorization", ana.bearer()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.privacyPolicyVersion").value(TestUsers.PRIVACY_VERSION))
                .andExpect(jsonPath("$.privacyAcceptedAt").isNotEmpty());
    }

    @Test
    void registrationWithoutConsentIsRejected() throws Exception {
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Ana\",\"email\":\"" + TestUsers.uniqueEmail()
                                + "\",\"password\":\"clave-segura-1\",\"acceptPrivacyPolicy\":false,"
                                + "\"privacyPolicyVersion\":\"2026-11\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.acceptPrivacyPolicy")
                        .value("Debe aceptar el aviso de privacidad para crear la cuenta."));
    }

    @Test
    void profileCanBeEditedAndOptionalFieldsCleared() throws Exception {
        send(put("/api/auth/me"), ana, """
                {"name":"Ana María","farmName":"La Esperanza","municipality":"Pasto","phone":"300 123 4567"}""")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Ana María"))
                .andExpect(jsonPath("$.farmName").value("La Esperanza"))
                .andExpect(jsonPath("$.municipality").value("Pasto"))
                .andExpect(jsonPath("$.phone").value("300 123 4567"));

        send(put("/api/auth/me"), ana, "{\"name\":\"Ana María\",\"farmName\":\"\",\"municipality\":\"Pasto\",\"phone\":\"\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.farmName").doesNotExist())
                .andExpect(jsonPath("$.phone").doesNotExist());

        // El perfil de otro usuario no cambia
        mvc.perform(get("/api/auth/me").header("Authorization", beto.bearer()))
                .andExpect(jsonPath("$.name").value("Ganadero"))
                .andExpect(jsonPath("$.municipality").doesNotExist());
    }

    @Test
    void profileValidationMessagesAreInSpanish() throws Exception {
        send(put("/api/auth/me"), ana, "{\"name\":\"\",\"phone\":\"llámame\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.name").value("El nombre es obligatorio."))
                .andExpect(jsonPath("$.errors.phone")
                        .value("Escriba el teléfono solo con números (por ejemplo, 3001234567)."));
    }

    @Test
    void changePasswordRequiresCurrentOneAndClosesOtherSessions() throws Exception {
        send(post("/api/auth/me/password"), ana, "{\"currentPassword\":\"no-es\",\"newPassword\":\"nueva-clave-22\"}")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("La contraseña no es correcta."));

        String body = send(post("/api/auth/me/password"), ana,
                "{\"currentPassword\":\"" + TestUsers.PASSWORD + "\",\"newPassword\":\"nueva-clave-22\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andReturn().getResponse().getContentAsString();
        String newRefresh = json.readTree(body).get("refreshToken").asText();

        mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + ana.refreshToken() + "\"}")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + newRefresh + "\"}")).andExpect(status().isOk());
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + ana.email() + "\",\"password\":\"nueva-clave-22\"}"))
                .andExpect(status().isOk());
    }

    @Test
    void deletingTheAccountRemovesAllItsDataAndOnlyItsData() throws Exception {
        UUID anaCow = seedData(ana);
        UUID betoCow = seedData(beto);

        send(delete("/api/auth/me"), ana, "{\"password\":\"equivocada\"}").andExpect(status().isUnauthorized());
        assertThat(count("SELECT count(*) FROM users WHERE id = ?", ana.id())).isEqualTo(1);

        send(delete("/api/auth/me"), ana, "{\"password\":\"" + TestUsers.PASSWORD + "\"}")
                .andExpect(status().isNoContent());

        assertThat(count("SELECT count(*) FROM users WHERE id = ?", ana.id())).isZero();
        assertThat(count("SELECT count(*) FROM cows WHERE owner_id = ?", ana.id())).isZero();
        assertThat(count("SELECT count(*) FROM daily_records WHERE cow_id = ?", anaCow)).isZero();
        assertThat(count("SELECT count(*) FROM inferences WHERE cow_id = ?", anaCow)).isZero();
        assertThat(count("SELECT count(*) FROM alerts WHERE cow_id = ?", anaCow)).isZero();
        assertThat(count("SELECT count(*) FROM refresh_tokens WHERE user_id = ?", ana.id())).isZero();
        assertThat(count("SELECT count(*) FROM email_codes WHERE user_id = ?", ana.id())).isZero();

        // Lo de Beto sigue intacto
        assertThat(count("SELECT count(*) FROM daily_records WHERE cow_id = ?", betoCow)).isEqualTo(1);
        assertThat(count("SELECT count(*) FROM alerts WHERE cow_id = ?", betoCow)).isEqualTo(1);

        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + ana.email() + "\",\"password\":\"" + TestUsers.PASSWORD + "\"}"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + ana.refreshToken() + "\"}")).andExpect(status().isUnauthorized());
    }

    @Test
    void privacyPolicyCanBeAcceptedLater() throws Exception {
        send(post("/api/auth/me/privacy"), ana, "{\"privacyPolicyVersion\":\"2027-01\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.privacyPolicyVersion").value("2027-01"));
    }

    @Test
    void profileEndpointsRequireSession() throws Exception {
        mvc.perform(put("/api/auth/me").contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"X\"}"))
                .andExpect(status().isUnauthorized());
        mvc.perform(delete("/api/auth/me").contentType(MediaType.APPLICATION_JSON).content("{\"password\":\"x\"}"))
                .andExpect(status().isUnauthorized());
    }
}
