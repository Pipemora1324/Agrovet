package co.edu.ucc.agrovet.cow;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
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
import co.edu.ucc.agrovet.TestUsers;
import co.edu.ucc.agrovet.TestUsers.TestUser;

class CowIntegrationTest extends IntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    JdbcTemplate jdbc;

    private TestUser ana;
    private TestUser beto;

    @BeforeEach
    void setUp() throws Exception {
        ana = TestUsers.register(mvc, json);
        beto = TestUsers.register(mvc, json);
    }

    private ResultActions postCow(TestUser user, String body) throws Exception {
        return mvc.perform(post("/api/cows").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private UUID createCow(TestUser user, String tag) throws Exception {
        UUID id = UUID.randomUUID();
        postCow(user, "{\"id\":\"" + id + "\",\"tag\":\"" + tag + "\",\"name\":\"Lucero\",\"breed\":\"Holstein\","
                + "\"calvings\":2,\"productionStatus\":\"LACTATING\"}")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(id.toString()));
        return id;
    }

    @Test
    void crudFlow() throws Exception {
        UUID id = createCow(ana, "A-001");

        mvc.perform(get("/api/cows/" + id).header("Authorization", ana.bearer()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tag").value("A-001"))
                .andExpect(jsonPath("$.productionStatus").value("LACTATING"));

        mvc.perform(put("/api/cows/" + id).header("Authorization", ana.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"tag\":\"A-001\",\"name\":\"Lucero\",\"productionStatus\":\"DRY\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.productionStatus").value("DRY"));

        mvc.perform(delete("/api/cows/" + id).header("Authorization", ana.bearer()))
                .andExpect(status().isNoContent());
        mvc.perform(get("/api/cows/" + id).header("Authorization", ana.bearer()))
                .andExpect(status().isNotFound());

        // Borrado lógico: la fila sigue en la base para la sincronización
        Boolean deleted = jdbc.queryForObject("SELECT deleted FROM cows WHERE id = ?", Boolean.class, id);
        assertThat(deleted).isTrue();
    }

    @Test
    void listShowsOnlyOwnCows() throws Exception {
        createCow(ana, "A-001");
        createCow(ana, "A-002");
        createCow(beto, "B-001");

        mvc.perform(get("/api/cows").header("Authorization", ana.bearer()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].tag").value("A-001"));
        mvc.perform(get("/api/cows").header("Authorization", beto.bearer()))
                .andExpect(jsonPath("$", hasSize(1)));
    }

    @Test
    void otherUserCannotReadUpdateDeleteOrSeeHistory() throws Exception {
        UUID anasCow = createCow(ana, "A-001");

        mvc.perform(get("/api/cows/" + anasCow).header("Authorization", beto.bearer()))
                .andExpect(status().isNotFound());
        mvc.perform(put("/api/cows/" + anasCow).header("Authorization", beto.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"tag\":\"ROBADA\",\"productionStatus\":\"DRY\"}"))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/cows/" + anasCow).header("Authorization", beto.bearer()))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/cows/" + anasCow + "/history").header("Authorization", beto.bearer()))
                .andExpect(status().isNotFound());

        // La vaca de Ana quedó intacta
        mvc.perform(get("/api/cows/" + anasCow).header("Authorization", ana.bearer()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tag").value("A-001"))
                .andExpect(jsonPath("$.productionStatus").value("LACTATING"));
    }

    @Test
    void otherUserCannotTakeOverIdWithPost() throws Exception {
        UUID anasCow = createCow(ana, "A-001");
        postCow(beto, "{\"id\":\"" + anasCow + "\",\"tag\":\"B-1\",\"productionStatus\":\"DRY\"}")
                .andExpect(status().isConflict());
        String owner = jdbc.queryForObject("SELECT owner_id::text FROM cows WHERE id = ?", String.class, anasCow);
        assertThat(owner).isEqualTo(ana.id().toString());
    }

    @Test
    void duplicateTagForSameOwnerIsRejectedButOtherOwnerMayUseIt() throws Exception {
        createCow(ana, "A-001");
        postCow(ana, "{\"tag\":\"A-001\",\"productionStatus\":\"DRY\"}").andExpect(status().isConflict());
        createCow(beto, "A-001");
    }

    @Test
    void invalidCowIsRejectedWithSpanishMessages() throws Exception {
        postCow(ana, "{\"tag\":\"\",\"calvings\":-1,\"birthDate\":\"2999-01-01\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.tag").value("El identificador de la vaca es obligatorio."))
                .andExpect(jsonPath("$.errors.calvings").value("El número de partos no puede ser negativo."))
                .andExpect(jsonPath("$.errors.birthDate").value("La fecha de nacimiento no puede ser futura."))
                .andExpect(jsonPath("$.errors.productionStatus").value("El estado productivo es obligatorio."));
        postCow(ana, "{\"tag\":\"X\",\"productionStatus\":\"VOLANDO\"}").andExpect(status().isBadRequest());
    }

    @Test
    void sqlInjectionInTagIsStoredAsPlainText() throws Exception {
        String tag = "x'); DROP TABLE cows; --";
        postCow(ana, "{\"tag\":\"" + tag + "\",\"productionStatus\":\"DRY\"}").andExpect(status().isCreated());
        Integer count = jdbc.queryForObject("SELECT count(*) FROM cows WHERE tag = ?", Integer.class, tag);
        assertThat(count).isEqualTo(1);
    }

    @Test
    void historyReturnsRecordsInRange() throws Exception {
        UUID cow = createCow(ana, "A-001");
        LocalDate today = LocalDate.now();
        for (int i = 0; i < 3; i++) {
            jdbc.update("INSERT INTO daily_records (id, cow_id, record_date, temperature_c, milk_l, feed_kg, "
                            + "abnormal_milk, created_at, updated_at) VALUES (?, ?, ?, 38.6, 12.5, 10.0, ?, now(), now())",
                    UUID.randomUUID(), cow, today.minusDays(i), i == 0);
        }

        mvc.perform(get("/api/cows/" + cow + "/history").header("Authorization", ana.bearer())
                        .param("from", today.minusDays(1).toString()).param("to", today.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.records", hasSize(2)))
                .andExpect(jsonPath("$.records[1].symptoms.abnormalMilk").value(true))
                .andExpect(jsonPath("$.records[0].milkL").value(12.5));

        mvc.perform(get("/api/cows/" + cow + "/history").header("Authorization", ana.bearer())
                        .param("from", today.toString()).param("to", today.minusDays(5).toString()))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/api/cows/" + cow + "/history").header("Authorization", ana.bearer())
                        .param("from", "no-es-fecha"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cowsRequireAuthentication() throws Exception {
        mvc.perform(get("/api/cows")).andExpect(status().isUnauthorized());
    }
}
