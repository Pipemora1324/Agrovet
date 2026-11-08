package co.edu.ucc.agrovet;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Registra y verifica usuarios nuevos en las pruebas de integración, por el mismo camino que la app. */
public final class TestUsers {

    public static final String PASSWORD = "clave-segura-1";

    private TestUsers() {
    }

    public record TestUser(UUID id, String email, String bearer, String refreshToken) {
    }

    public static String uniqueEmail() {
        return "u" + UUID.randomUUID().toString().substring(0, 8) + "@correo.co";
    }

    /** Registro + código del correo + verificación. Devuelve la sesión abierta. */
    public static TestUser register(MockMvc mvc, ObjectMapper json, RecordingEmailSender mail) throws Exception {
        String email = uniqueEmail();
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(registerBody("Ganadero", email, PASSWORD)))
                .andExpect(status().isAccepted());
        String body = mvc.perform(post("/api/auth/verify-email").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"code\":\"" + mail.lastCode(email) + "\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        JsonNode node = json.readTree(body);
        return new TestUser(UUID.fromString(node.get("user").get("id").asText()), email,
                "Bearer " + node.get("accessToken").asText(), node.get("refreshToken").asText());
    }

    public static String registerBody(String name, String email, String password) {
        return "{\"name\":\"" + name + "\",\"email\":\"" + email + "\",\"password\":\"" + password + "\"}";
    }
}
