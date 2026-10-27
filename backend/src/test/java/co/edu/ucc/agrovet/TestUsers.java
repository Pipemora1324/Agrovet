package co.edu.ucc.agrovet;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Registra usuarios nuevos en las pruebas de integración. */
public final class TestUsers {

    private TestUsers() {
    }

    public record TestUser(UUID id, String email, String bearer) {
    }

    public static TestUser register(MockMvc mvc, ObjectMapper json) throws Exception {
        String email = "u" + UUID.randomUUID().toString().substring(0, 8) + "@correo.co";
        String body = mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Ganadero\",\"email\":\"" + email + "\",\"password\":\"clave-segura-1\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        JsonNode node = json.readTree(body);
        return new TestUser(UUID.fromString(node.get("user").get("id").asText()), email,
                "Bearer " + node.get("accessToken").asText());
    }
}
