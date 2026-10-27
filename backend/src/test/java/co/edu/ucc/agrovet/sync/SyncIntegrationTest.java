package co.edu.ucc.agrovet.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import co.edu.ucc.agrovet.IntegrationTest;
import co.edu.ucc.agrovet.TestUsers;
import co.edu.ucc.agrovet.TestUsers.TestUser;

class SyncIntegrationTest extends IntegrationTest {

    private static final Instant T1 = Instant.parse("2026-03-01T08:00:00Z");
    private static final Instant T2 = Instant.parse("2026-03-02T08:00:00Z");

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

    private ResultActions sync(TestUser user, Map<String, Object> batch) throws Exception {
        return mvc.perform(post("/api/sync").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(batch)));
    }

    private JsonNode syncOk(TestUser user, Map<String, Object> batch) throws Exception {
        String body = sync(user, batch).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(body);
    }

    private static Map<String, Object> cow(UUID id, String tag, String status, Instant updatedAt) {
        Map<String, Object> cow = new HashMap<>();
        cow.put("id", id);
        cow.put("tag", tag);
        cow.put("productionStatus", status);
        cow.put("updatedAt", updatedAt);
        return cow;
    }

    private static Map<String, Object> record(UUID id, UUID cowId, LocalDate date, double milk, Instant updatedAt) {
        Map<String, Object> record = new HashMap<>();
        record.put("id", id);
        record.put("cowId", cowId);
        record.put("recordDate", date);
        record.put("temperatureC", 38.7);
        record.put("milkL", milk);
        record.put("feedKg", 10.5);
        record.put("abnormalMilk", true);
        record.put("updatedAt", updatedAt);
        return record;
    }

    private static Map<String, Object> inference(UUID id, UUID cowId, double probability, String level) {
        return Map.of("id", id, "cowId", cowId, "windowEndDate", LocalDate.of(2026, 3, 2), "probability",
                probability, "riskLevel", level, "modelVersion", "1.0.0-synthetic", "updatedAt", T1);
    }

    private int count(String table, UUID cowId) {
        return jdbc.queryForObject("SELECT count(*) FROM " + table + " WHERE cow_id = ?", Integer.class, cowId);
    }

    @Test
    void sameBatchTwiceCreatesNoDuplicates() throws Exception {
        UUID cowId = UUID.randomUUID();
        UUID r1 = UUID.randomUUID();
        UUID r2 = UUID.randomUUID();
        UUID inf = UUID.randomUUID();
        UUID alert = UUID.randomUUID();
        Map<String, Object> batch = Map.of(
                "cows", List.of(cow(cowId, "S-001", "LACTATING", T1)),
                "dailyRecords", List.of(record(r1, cowId, LocalDate.of(2026, 3, 1), 12.0, T1),
                        record(r2, cowId, LocalDate.of(2026, 3, 2), 11.0, T1)),
                "inferences", List.of(inference(inf, cowId, 0.9, "RED")),
                "alerts", List.of(Map.of("id", alert, "cowId", cowId, "inferenceId", inf, "riskLevel", "RED",
                        "updatedAt", T1)));

        JsonNode first = syncOk(ana, batch);
        JsonNode second = syncOk(ana, batch);

        for (JsonNode response : List.of(first, second)) {
            assertThat(response.get("rejected")).isEmpty();
            assertThat(response.get("confirmed").get("cows")).hasSize(1);
            assertThat(response.get("confirmed").get("dailyRecords")).hasSize(2);
            assertThat(response.get("confirmed").get("inferences")).hasSize(1);
            assertThat(response.get("confirmed").get("alerts")).hasSize(1);
        }
        assertThat(jdbc.queryForObject("SELECT count(*) FROM cows WHERE id = ?", Integer.class, cowId)).isEqualTo(1);
        assertThat(count("daily_records", cowId)).isEqualTo(2);
        assertThat(count("inferences", cowId)).isEqualTo(1);
        assertThat(count("alerts", cowId)).isEqualTo(1);
    }

    @Test
    void olderVersionDoesNotOverwriteNewerOne() throws Exception {
        UUID cowId = UUID.randomUUID();
        UUID recordId = UUID.randomUUID();
        syncOk(ana, Map.of("cows", List.of(cow(cowId, "S-002", "LACTATING", T2)),
                "dailyRecords", List.of(record(recordId, cowId, LocalDate.of(2026, 3, 2), 15.0, T2))));

        JsonNode response = syncOk(ana, Map.of("cows", List.of(cow(cowId, "S-002", "DRY", T1)),
                "dailyRecords", List.of(record(recordId, cowId, LocalDate.of(2026, 3, 2), 3.0, T1))));

        assertThat(response.get("confirmed").get("cows").get(0).asText()).isEqualTo(cowId.toString());
        assertThat(jdbc.queryForObject("SELECT production_status FROM cows WHERE id = ?", String.class, cowId))
                .isEqualTo("LACTATING");
        assertThat(jdbc.queryForObject("SELECT milk_l FROM daily_records WHERE id = ?", Double.class, recordId))
                .isEqualTo(15.0);
    }

    @Test
    void newerVersionUpdates() throws Exception {
        UUID cowId = UUID.randomUUID();
        syncOk(ana, Map.of("cows", List.of(cow(cowId, "S-003", "LACTATING", T1))));
        syncOk(ana, Map.of("cows", List.of(cow(cowId, "S-003", "DRY", T2))));
        assertThat(jdbc.queryForObject("SELECT production_status FROM cows WHERE id = ?", String.class, cowId))
                .isEqualTo("DRY");
    }

    @Test
    void otherUserCannotOverwriteOrAttachToForeignData() throws Exception {
        UUID anasCow = UUID.randomUUID();
        UUID anasRecord = UUID.randomUUID();
        syncOk(ana, Map.of("cows", List.of(cow(anasCow, "A-1", "LACTATING", T1)),
                "dailyRecords", List.of(record(anasRecord, anasCow, LocalDate.of(2026, 3, 1), 12.0, T1))));

        UUID betosCow = UUID.randomUUID();
        JsonNode response = syncOk(beto, Map.of(
                "cows", List.of(cow(anasCow, "ROBADA", "DRY", T2), cow(betosCow, "B-1", "DRY", T1)),
                "dailyRecords", List.of(
                        record(UUID.randomUUID(), anasCow, LocalDate.of(2026, 3, 3), 1.0, T2),
                        record(anasRecord, betosCow, LocalDate.of(2026, 3, 1), 1.0, T2))));

        assertThat(response.get("confirmed").get("cows")).hasSize(1);
        assertThat(response.get("confirmed").get("cows").get(0).asText()).isEqualTo(betosCow.toString());
        assertThat(response.get("confirmed").get("dailyRecords")).isEmpty();
        assertThat(response.get("rejected")).hasSize(3);

        assertThat(jdbc.queryForObject("SELECT tag FROM cows WHERE id = ?", String.class, anasCow)).isEqualTo("A-1");
        assertThat(jdbc.queryForObject("SELECT owner_id::text FROM cows WHERE id = ?", String.class, anasCow))
                .isEqualTo(ana.id().toString());
        assertThat(count("daily_records", anasCow)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT milk_l FROM daily_records WHERE id = ?", Double.class, anasRecord))
                .isEqualTo(12.0);
    }

    @Test
    void recordForUnknownCowIsRejected() throws Exception {
        UUID recordId = UUID.randomUUID();
        JsonNode response = syncOk(ana, Map.of("dailyRecords",
                List.of(record(recordId, UUID.randomUUID(), LocalDate.of(2026, 3, 1), 12.0, T1))));
        assertThat(response.get("rejected").get(0).get("id").asText()).isEqualTo(recordId.toString());
        assertThat(response.get("rejected").get(0).get("reason").asText())
                .isEqualTo("La vaca no existe o no pertenece al usuario.");
    }

    @Test
    void secondRecordForSameDayIsRejected() throws Exception {
        UUID cowId = UUID.randomUUID();
        JsonNode response = syncOk(ana, Map.of("cows", List.of(cow(cowId, "S-004", "LACTATING", T1)),
                "dailyRecords", List.of(record(UUID.randomUUID(), cowId, LocalDate.of(2026, 3, 1), 12.0, T1),
                        record(UUID.randomUUID(), cowId, LocalDate.of(2026, 3, 1), 13.0, T1))));
        assertThat(response.get("confirmed").get("dailyRecords")).hasSize(1);
        assertThat(response.get("rejected")).hasSize(1);
        assertThat(count("daily_records", cowId)).isEqualTo(1);
    }

    @Test
    void invalidValuesAreRejectedWithBadRequest() throws Exception {
        UUID cowId = UUID.randomUUID();
        sync(ana, Map.of("cows", List.of(cow(cowId, "S-005", "LACTATING", T1)),
                "inferences", List.of(inference(UUID.randomUUID(), cowId, 1.5, "RED"))))
                .andExpect(status().isBadRequest());
        Map<String, Object> hot = record(UUID.randomUUID(), cowId, LocalDate.of(2026, 3, 1), 12.0, T1);
        hot.put("temperatureC", 60.0);
        sync(ana, Map.of("dailyRecords", List.of(hot))).andExpect(status().isBadRequest());
        // Nada del lote inválido quedó guardado
        assertThat(jdbc.queryForObject("SELECT count(*) FROM cows WHERE id = ?", Integer.class, cowId)).isZero();
    }

    @Test
    void deletionThroughSyncHidesCow() throws Exception {
        UUID cowId = UUID.randomUUID();
        syncOk(ana, Map.of("cows", List.of(cow(cowId, "S-006", "LACTATING", T1))));
        Map<String, Object> deleted = cow(cowId, "S-006", "LACTATING", T2);
        deleted.put("deleted", true);
        syncOk(ana, Map.of("cows", List.of(deleted)));

        mvc.perform(get("/api/cows/" + cowId).header("Authorization", ana.bearer())).andExpect(status().isNotFound());
    }

    @Test
    void syncedDataAppearsInHistory() throws Exception {
        UUID cowId = UUID.randomUUID();
        syncOk(ana, Map.of("cows", List.of(cow(cowId, "S-007", "LACTATING", T1)),
                "dailyRecords", List.of(record(UUID.randomUUID(), cowId, LocalDate.of(2026, 3, 1), 12.0, T1),
                        record(UUID.randomUUID(), cowId, LocalDate.of(2026, 3, 2), 11.0, T1)),
                "inferences", List.of(inference(UUID.randomUUID(), cowId, 0.6, "YELLOW"))));

        mvc.perform(get("/api/cows/" + cowId + "/history").header("Authorization", ana.bearer())
                        .param("from", "2026-03-01").param("to", "2026-03-02"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.records", hasSize(2)))
                .andExpect(jsonPath("$.records[0].symptoms.abnormalMilk").value(true))
                .andExpect(jsonPath("$.inferences[0].riskLevel").value("YELLOW"));
    }

    @Test
    void syncRequiresAuthentication() throws Exception {
        mvc.perform(post("/api/sync").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
    }
}
