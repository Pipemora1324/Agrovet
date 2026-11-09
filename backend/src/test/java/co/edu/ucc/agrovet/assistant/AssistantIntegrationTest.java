package co.edu.ucc.agrovet.assistant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import com.fasterxml.jackson.databind.ObjectMapper;

import co.edu.ucc.agrovet.FakeLlmClient;
import co.edu.ucc.agrovet.IntegrationTest;
import co.edu.ucc.agrovet.RecordingEmailSender;
import co.edu.ucc.agrovet.TestUsers;
import co.edu.ucc.agrovet.TestUsers.TestUser;
import co.edu.ucc.agrovet.TestImages;

class AssistantIntegrationTest extends IntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    RecordingEmailSender mail;
    @Autowired
    FakeLlmClient llm;

    private TestUser ana;

    @BeforeEach
    void setUp() throws Exception {
        ana = TestUsers.register(mvc, json, mail);
        llm.failing = false;
    }

    @AfterEach
    void tearDown() {
        llm.failing = false;
    }

    private ResultActions ask(TestUser user, String body) throws Exception {
        return mvc.perform(post("/api/assistant/chat").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(body));
    }

    @Test
    void answersWithCowContextAndTheFixedRules() throws Exception {
        ask(ana, """
                {"question":"¿Qué hago si la leche sale con grumos?",
                 "context":{"riskLevel":"YELLOW","cause":"SYMPTOMS","symptomScore":3,
                            "symptoms":["Grumos o sangre en la leche"]},
                 "history":[{"fromUser":true,"text":"Hola"},{"fromUser":false,"text":"Hola, ¿en qué le ayudo?"}]}
                """)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.answer").value(org.hamcrest.Matchers.containsString("veterinario")));

        assertThat(llm.lastSystemPrompt).contains("Oriente, no diagnostique")
                .contains("describa solo lo que se ve")
                .contains("llamar al veterinario")
                .contains("máximo 5 frases");
        String context = llm.lastTurns.getFirst().text();
        assertThat(context).contains("amarillo").contains("los síntomas del día").contains("Grumos");
        // Al proveedor no le llega quién es el usuario
        assertThat(llm.lastTurns.toString()).doesNotContain(ana.email()).doesNotContain(ana.id().toString());
        assertThat(llm.lastTurns.getLast().text()).isEqualTo("¿Qué hago si la leche sale con grumos?");
        assertThat(llm.lastTurns).hasSize(5);
        assertThat(llm.lastPhoto).isNull();
    }

    @Test
    void photoReachesTheProviderWithoutLocation() throws Exception {
        byte[] withGps = TestImages.withGpsExif(TestImages.image("jpg", 32, 32));
        String base64 = Base64.getEncoder().encodeToString(withGps);
        ask(ana, "{\"question\":\"¿Cómo ve esta ubre?\",\"photoBase64\":\"" + base64 + "\"}")
                .andExpect(status().isOk());
        assertThat(llm.lastPhoto).isNotNull();
        assertThat(new String(llm.lastPhoto, StandardCharsets.ISO_8859_1)).doesNotContain("GPS");

        ask(ana, "{\"question\":\"¿Y esta?\",\"photoBase64\":\""
                + Base64.getEncoder().encodeToString("no es foto".getBytes(StandardCharsets.UTF_8)) + "\"}")
                .andExpect(status().isBadRequest());
    }

    @Test
    void eachUserHasALimitPerHour() throws Exception {
        TestUser beto = TestUsers.register(mvc, json, mail);
        for (int i = 0; i < 3; i++) {
            ask(beto, "{\"question\":\"Pregunta " + i + "\"}").andExpect(status().isOk());
        }
        ask(beto, "{\"question\":\"Una más\"}").andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
        // El límite de Beto no afecta a Ana
        ask(ana, "{\"question\":\"Hola\"}").andExpect(status().isOk());
    }

    @Test
    void providerFailureIsReportedAsUnavailable() throws Exception {
        llm.failing = true;
        ask(ana, "{\"question\":\"Hola\"}").andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.detail").value("El asistente no está disponible en este momento. Intente más tarde."));
    }

    @Test
    void validationAndAuthentication() throws Exception {
        ask(ana, "{\"question\":\"\"}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.question").value("Escriba su pregunta."));
        mvc.perform(post("/api/assistant/chat").contentType(MediaType.APPLICATION_JSON).content("{\"question\":\"x\"}"))
                .andExpect(status().isUnauthorized());
    }
}
