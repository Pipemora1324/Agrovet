package co.edu.ucc.agrovet;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import co.edu.ucc.agrovet.config.CorsProperties;
import co.edu.ucc.agrovet.mail.MailSettings;

/** Perfil "prod": Swagger apagado, chequeo de salud listo, SMTP real obligatorio y CORS cerrado. */
@SpringBootTest(properties = {
        // Credenciales de mentira: el correo no sale, lo recibe RecordingEmailSender
        "agrovet.mail.username=prueba@correo.co",
        "agrovet.mail.password=clave-de-prueba" })
@AutoConfigureMockMvc
@ActiveProfiles({ "test", "prod" })
@Import({ TestcontainersConfiguration.class, TestMailConfiguration.class })
class ProdProfileIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    MailSettings mail;

    @Autowired
    CorsProperties cors;

    @Test
    void swaggerYLaDescripcionDeLaApiEstanApagados() throws Exception {
        mvc.perform(get("/v3/api-docs")).andExpect(status().isNotFound());
        mvc.perform(get("/swagger-ui.html")).andExpect(status().isNotFound());
    }

    @Test
    void elChequeoDeSaludRespondeSinDetalles() throws Exception {
        mvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.components").doesNotExist());
        mvc.perform(get("/actuator/health/liveness")).andExpect(status().isOk());
        mvc.perform(get("/actuator/health/readiness")).andExpect(status().isOk());
    }

    @Test
    void exigeSmtpRealYCorsSinOrigenes() {
        assertThat(mail.requireSmtp()).isTrue();
        assertThat(mail.usesRealSmtp()).isTrue();
        assertThat(cors.allowedOrigins()).isEmpty();
    }

    @Test
    void laApiSigueProtegida() throws Exception {
        mvc.perform(get("/api/cows")).andExpect(status().isUnauthorized());
    }
}
