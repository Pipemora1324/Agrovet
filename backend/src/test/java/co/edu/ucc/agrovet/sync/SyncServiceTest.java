package co.edu.ucc.agrovet.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import co.edu.ucc.agrovet.alert.Alert;
import co.edu.ucc.agrovet.alert.AlertRepository;
import co.edu.ucc.agrovet.cow.Cow;
import co.edu.ucc.agrovet.cow.CowRepository;
import co.edu.ucc.agrovet.cow.ProductionStatus;
import co.edu.ucc.agrovet.inference.Inference;
import co.edu.ucc.agrovet.inference.InferenceRepository;
import co.edu.ucc.agrovet.inference.RiskCause;
import co.edu.ucc.agrovet.inference.RiskLevel;
import co.edu.ucc.agrovet.photo.CowPhoto;
import co.edu.ucc.agrovet.photo.CowPhotoRepository;
import co.edu.ucc.agrovet.photo.Diagnosis;
import co.edu.ucc.agrovet.photo.PhotoStorage;
import co.edu.ucc.agrovet.photo.VetConfirmation;
import co.edu.ucc.agrovet.record.DailyRecord;
import co.edu.ucc.agrovet.record.DailyRecordRepository;
import co.edu.ucc.agrovet.record.Symptoms;
import co.edu.ucc.agrovet.record.ValueSources;
import co.edu.ucc.agrovet.sync.SyncDtos.AlertSync;
import co.edu.ucc.agrovet.sync.SyncDtos.CowSync;
import co.edu.ucc.agrovet.sync.SyncDtos.DailyRecordSync;
import co.edu.ucc.agrovet.sync.SyncDtos.InferenceSync;
import co.edu.ucc.agrovet.sync.SyncDtos.PhotoSync;
import co.edu.ucc.agrovet.sync.SyncDtos.Rejected;
import co.edu.ucc.agrovet.sync.SyncDtos.SyncRequest;
import co.edu.ucc.agrovet.sync.SyncDtos.SyncResponse;

/**
 * Reglas de la sincronización sin base de datos: dueño, última modificación, duplicados y rechazos.
 * El recorrido completo por HTTP y PostgreSQL está en SyncIntegrationTest.
 */
class SyncServiceTest {

    private static final Instant NOW = Instant.parse("2026-11-01T12:00:00Z");
    private static final Instant T1 = Instant.parse("2026-10-01T08:00:00Z");
    private static final Instant T2 = T1.plusSeconds(60);
    private static final Instant T3 = T2.plusSeconds(60);
    private static final LocalDate DAY = LocalDate.of(2026, 10, 1);
    private static final UUID OWNER = UUID.randomUUID();
    private static final UUID OTHER = UUID.randomUUID();

    private final CowRepository cows = mock(CowRepository.class);
    private final DailyRecordRepository records = mock(DailyRecordRepository.class);
    private final InferenceRepository inferences = mock(InferenceRepository.class);
    private final AlertRepository alerts = mock(AlertRepository.class);
    private final CowPhotoRepository photos = mock(CowPhotoRepository.class);
    private final PhotoStorage storage = mock(PhotoStorage.class);
    private final SyncService service = new SyncService(cows, records, inferences, alerts, photos, storage,
            Clock.fixed(NOW, ZoneOffset.UTC));

    // ---- Datos de prueba ----

    private static CowSync cowSync(UUID id, String tag, Instant updatedAt, boolean deleted) {
        return new CowSync(id, tag, "Lola", "Holstein", DAY.minusYears(3), 2, ProductionStatus.LACTATING,
                updatedAt, deleted);
    }

    private static DailyRecordSync recordSync(UUID id, UUID cowId, Instant updatedAt, boolean deleted) {
        return new DailyRecordSync(id, cowId, DAY, 38.9, 12.5, 10.0, true, false, true, false, true, false,
                Boolean.TRUE, Boolean.FALSE, "measured", "estimated", null, "Revisar", updatedAt, deleted);
    }

    private static InferenceSync inferenceSync(UUID id, UUID cowId, Double probability, Integer score,
            Instant updatedAt) {
        return new InferenceSync(id, cowId, DAY, probability, score, RiskCause.MODEL, RiskLevel.RED, "lstm-v1",
                updatedAt, false);
    }

    private static AlertSync alertSync(UUID id, UUID cowId, UUID inferenceId, RiskLevel level, Instant updatedAt) {
        return new AlertSync(id, cowId, inferenceId, level, true, T1, updatedAt, false);
    }

    private static PhotoSync photoSync(UUID id, UUID cowId, Instant updatedAt, boolean deleted) {
        return new PhotoSync(id, cowId, DAY, VetConfirmation.YES, Diagnosis.MASTITIS, "Cuarto trasero", true,
                updatedAt, deleted);
    }

    private static SyncRequest cowsOnly(CowSync... items) {
        return new SyncRequest(List.of(items), null, null, null, null);
    }

    private static Cow storedCow(UUID id, UUID owner, String tag, Instant updatedAt) {
        Cow cow = new Cow(id, owner, T1);
        cow.update(tag, null, null, null, null, ProductionStatus.DRY, updatedAt);
        return cow;
    }

    /** Vaca del usuario que ya está en el servidor y no viene en el lote. */
    private UUID ownedCow() {
        UUID id = UUID.randomUUID();
        when(cows.findById(id)).thenReturn(Optional.of(storedCow(id, OWNER, "F-1", T1)));
        return id;
    }

    private UUID foreignCow() {
        UUID id = UUID.randomUUID();
        when(cows.findById(id)).thenReturn(Optional.of(storedCow(id, OTHER, "X-1", T1)));
        return id;
    }

    private static void assertRejected(SyncResponse response, String entity, UUID id, String reason) {
        assertThat(response.rejected()).containsExactly(new Rejected(entity, id, reason));
    }

    // ---- Vacas ----

    @Test
    void newCowIsCreatedWithTrimmedTagAndConfirmed() {
        UUID id = UUID.randomUUID();
        SyncResponse response = service.sync(OWNER, cowsOnly(cowSync(id, "  F-7 ", T2, false)));

        ArgumentCaptor<Cow> saved = ArgumentCaptor.forClass(Cow.class);
        verify(cows).saveAndFlush(saved.capture());
        Cow cow = saved.getValue();
        assertThat(cow.getId()).isEqualTo(id);
        assertThat(cow.getOwnerId()).isEqualTo(OWNER);
        assertThat(cow.getTag()).isEqualTo("F-7");
        assertThat(cow.getName()).isEqualTo("Lola");
        assertThat(cow.getBreed()).isEqualTo("Holstein");
        assertThat(cow.getBirthDate()).isEqualTo(DAY.minusYears(3));
        assertThat(cow.getCalvings()).isEqualTo(2);
        assertThat(cow.getProductionStatus()).isEqualTo(ProductionStatus.LACTATING);
        assertThat(cow.getUpdatedAt()).isEqualTo(T2);
        assertThat(cow.isDeleted()).isFalse();
        verify(cows).existsByOwnerIdAndTagAndDeletedFalseAndIdNot(OWNER, "F-7", id);

        assertThat(response.confirmed().cows()).containsExactly(id);
        assertThat(response.rejected()).isEmpty();
        assertThat(response.serverTime()).isEqualTo(NOW);
    }

    @Test
    void cowOfAnotherUserIsRejectedAndNotTouched() {
        UUID id = UUID.randomUUID();
        Cow foreign = storedCow(id, OTHER, "X-1", T1);
        when(cows.findById(id)).thenReturn(Optional.of(foreign));

        SyncResponse response = service.sync(OWNER, cowsOnly(cowSync(id, "F-1", T3, false)));

        assertRejected(response, "cow", id, SyncService.NOT_OWNED);
        assertThat(response.confirmed().cows()).isEmpty();
        assertThat(foreign.getTag()).isEqualTo("X-1");
        verify(cows, never()).saveAndFlush(any());
    }

    @Test
    void duplicateActiveTagIsRejected() {
        UUID id = UUID.randomUUID();
        when(cows.existsByOwnerIdAndTagAndDeletedFalseAndIdNot(OWNER, "F-1", id)).thenReturn(true);

        SyncResponse response = service.sync(OWNER, cowsOnly(cowSync(id, "F-1", T2, false)));

        assertRejected(response, "cow", id, "Ya existe otra vaca activa con el identificador F-1.");
        verify(cows, never()).saveAndFlush(any());
    }

    @Test
    void deletedCowDoesNotCheckTagAndIsMarkedDeleted() {
        UUID id = UUID.randomUUID();
        when(cows.existsByOwnerIdAndTagAndDeletedFalseAndIdNot(any(), any(), any())).thenReturn(true);

        SyncResponse response = service.sync(OWNER, cowsOnly(cowSync(id, "F-1", T2, true)));

        assertThat(response.confirmed().cows()).containsExactly(id);
        verify(cows, never()).existsByOwnerIdAndTagAndDeletedFalseAndIdNot(any(), any(), any());
        ArgumentCaptor<Cow> saved = ArgumentCaptor.forClass(Cow.class);
        verify(cows).saveAndFlush(saved.capture());
        assertThat(saved.getValue().isDeleted()).isTrue();
    }

    @Test
    void olderVersionIsKeptButStillConfirmed() {
        UUID id = UUID.randomUUID();
        Cow stored = storedCow(id, OWNER, "NUEVA", T2);
        when(cows.findById(id)).thenReturn(Optional.of(stored));

        SyncResponse response = service.sync(OWNER, cowsOnly(cowSync(id, "VIEJA", T1, false)));

        assertThat(response.confirmed().cows()).containsExactly(id);
        assertThat(stored.getTag()).isEqualTo("NUEVA");
        assertThat(stored.getUpdatedAt()).isEqualTo(T2);
        verify(cows, never()).saveAndFlush(any());
    }

    @Test
    void sameOrNewerVersionIsApplied() {
        UUID id = UUID.randomUUID();
        Cow stored = storedCow(id, OWNER, "A", T2);
        when(cows.findById(id)).thenReturn(Optional.of(stored));

        // Reenviar la misma versión se aplica (no cambia nada) y una más reciente la reemplaza
        service.sync(OWNER, cowsOnly(cowSync(id, "B", T2, false)));
        assertThat(stored.getTag()).isEqualTo("B");
        service.sync(OWNER, cowsOnly(cowSync(id, "C", T3, false)));
        assertThat(stored.getTag()).isEqualTo("C");
        assertThat(stored.getUpdatedAt()).isEqualTo(T3);
        verify(cows, times(2)).saveAndFlush(stored);
    }

    // ---- Registros diarios ----

    @Test
    void recordOfCowCreatedInTheSameBatchIsAcceptedWithAllFields() {
        UUID cowId = UUID.randomUUID();
        UUID recordId = UUID.randomUUID();
        SyncRequest request = new SyncRequest(List.of(cowSync(cowId, "F-1", T1, false)),
                List.of(recordSync(recordId, cowId, T2, false)), null, null, null);

        SyncResponse response = service.sync(OWNER, request);

        assertThat(response.confirmed().dailyRecords()).containsExactly(recordId);
        // La propiedad de la vaca se recuerda del lote: no se vuelve a consultar
        verify(cows, times(1)).findById(cowId);
        ArgumentCaptor<DailyRecord> saved = ArgumentCaptor.forClass(DailyRecord.class);
        verify(records).saveAndFlush(saved.capture());
        DailyRecord record = saved.getValue();
        assertThat(record.getId()).isEqualTo(recordId);
        assertThat(record.getCowId()).isEqualTo(cowId);
        assertThat(record.getRecordDate()).isEqualTo(DAY);
        assertThat(record.getTemperatureC()).isEqualTo(38.9);
        assertThat(record.getMilkL()).isEqualTo(12.5);
        assertThat(record.getFeedKg()).isEqualTo(10.0);
        assertThat(record.getSymptoms())
                .isEqualTo(new Symptoms(true, false, true, false, true, false, Boolean.TRUE, Boolean.FALSE));
        assertThat(record.getSources()).isEqualTo(new ValueSources("measured", "estimated", null));
        assertThat(record.getNotes()).isEqualTo("Revisar");
        assertThat(record.getUpdatedAt()).isEqualTo(T2);
        verify(records).existsByCowIdAndRecordDateAndDeletedFalseAndIdNot(cowId, DAY, recordId);
    }

    @Test
    void ownershipOfStoredCowIsLookedUpOncePerBatch() {
        UUID cowId = ownedCow();
        UUID first = UUID.randomUUID();
        UUID second = UUID.randomUUID();
        SyncRequest request = new SyncRequest(null,
                List.of(recordSync(first, cowId, T1, false), recordSync(second, cowId, T1, false)), null, null, null);

        SyncResponse response = service.sync(OWNER, request);

        assertThat(response.confirmed().dailyRecords()).containsExactly(first, second);
        verify(cows, times(1)).findById(cowId);
    }

    @Test
    void recordOfForeignOrUnknownCowIsRejected() {
        UUID foreign = foreignCow();
        UUID unknown = UUID.randomUUID();
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();
        SyncRequest request = new SyncRequest(null,
                List.of(recordSync(a, foreign, T1, false), recordSync(b, unknown, T1, false)), null, null, null);

        SyncResponse response = service.sync(OWNER, request);

        assertThat(response.rejected()).containsExactly(
                new Rejected("dailyRecord", a, SyncService.COW_NOT_FOUND),
                new Rejected("dailyRecord", b, SyncService.COW_NOT_FOUND));
        assertThat(response.confirmed().dailyRecords()).isEmpty();
        verify(records, never()).saveAndFlush(any());
    }

    @Test
    void storedRecordOfAnotherUserCannotBeMovedToOwnCow() {
        UUID mine = ownedCow();
        UUID foreign = foreignCow();
        UUID id = UUID.randomUUID();
        DailyRecord stored = new DailyRecord(id, T1);
        stored.update(foreign, DAY, 38.0, 10.0, 9.0, Symptoms.NONE, ValueSources.NONE, null, false, T1);
        when(records.findById(id)).thenReturn(Optional.of(stored));

        SyncResponse response = service.sync(OWNER,
                new SyncRequest(null, List.of(recordSync(id, mine, T3, false)), null, null, null));

        assertRejected(response, "dailyRecord", id, SyncService.NOT_OWNED);
        assertThat(stored.getCowId()).isEqualTo(foreign);
    }

    @Test
    void secondActiveRecordForTheSameDayIsRejected() {
        UUID cowId = ownedCow();
        UUID id = UUID.randomUUID();
        when(records.existsByCowIdAndRecordDateAndDeletedFalseAndIdNot(cowId, DAY, id)).thenReturn(true);

        SyncResponse response = service.sync(OWNER,
                new SyncRequest(null, List.of(recordSync(id, cowId, T1, false)), null, null, null));

        assertRejected(response, "dailyRecord", id, "Ya existe otro registro de esa vaca para ese día.");
        verify(records, never()).saveAndFlush(any());
    }

    @Test
    void deletedRecordSkipsDuplicateDayCheck() {
        UUID cowId = ownedCow();
        UUID id = UUID.randomUUID();
        when(records.existsByCowIdAndRecordDateAndDeletedFalseAndIdNot(any(), any(), any())).thenReturn(true);

        SyncResponse response = service.sync(OWNER,
                new SyncRequest(null, List.of(recordSync(id, cowId, T1, true)), null, null, null));

        assertThat(response.confirmed().dailyRecords()).containsExactly(id);
        verify(records, never()).existsByCowIdAndRecordDateAndDeletedFalseAndIdNot(any(), any(), any());
        verify(records).saveAndFlush(any());
    }

    @Test
    void olderRecordVersionIsNotApplied() {
        UUID cowId = ownedCow();
        UUID id = UUID.randomUUID();
        DailyRecord stored = new DailyRecord(id, T1);
        stored.update(cowId, DAY, 38.0, 10.0, 9.0, Symptoms.NONE, ValueSources.NONE, "nuevo", false, T3);
        when(records.findById(id)).thenReturn(Optional.of(stored));

        SyncResponse response = service.sync(OWNER,
                new SyncRequest(null, List.of(recordSync(id, cowId, T2, false)), null, null, null));

        assertThat(response.confirmed().dailyRecords()).containsExactly(id);
        assertThat(stored.getNotes()).isEqualTo("nuevo");
        verify(records, never()).saveAndFlush(any());
    }

    // ---- Inferencias ----

    @Test
    void inferenceNeedsProbabilityOrSymptomScore() {
        UUID cowId = ownedCow();
        UUID none = UUID.randomUUID();
        UUID onlyModel = UUID.randomUUID();
        UUID onlySymptoms = UUID.randomUUID();
        SyncRequest request = new SyncRequest(null, null, List.of(
                inferenceSync(none, cowId, null, null, T1),
                inferenceSync(onlyModel, cowId, 0.91, null, T1),
                inferenceSync(onlySymptoms, cowId, null, 7, T1)), null, null);

        SyncResponse response = service.sync(OWNER, request);

        assertRejected(response, "inference", none,
                "La evaluación no trae ni probabilidad del modelo ni puntaje de síntomas.");
        assertThat(response.confirmed().inferences()).containsExactly(onlyModel, onlySymptoms);
        verify(inferences, times(2)).saveAndFlush(any());
    }

    @Test
    void inferenceFieldsAreStored() {
        UUID cowId = ownedCow();
        UUID id = UUID.randomUUID();

        service.sync(OWNER, new SyncRequest(null, null, List.of(inferenceSync(id, cowId, 0.91, 4, T2)), null, null));

        ArgumentCaptor<Inference> saved = ArgumentCaptor.forClass(Inference.class);
        verify(inferences).saveAndFlush(saved.capture());
        Inference inference = saved.getValue();
        assertThat(inference.getId()).isEqualTo(id);
        assertThat(inference.getCowId()).isEqualTo(cowId);
        assertThat(inference.getWindowEndDate()).isEqualTo(DAY);
        assertThat(inference.getProbability()).isEqualTo(0.91);
        assertThat(inference.getSymptomScore()).isEqualTo(4);
        assertThat(inference.getCause()).isEqualTo(RiskCause.MODEL);
        assertThat(inference.getRiskLevel()).isEqualTo(RiskLevel.RED);
        assertThat(inference.getModelVersion()).isEqualTo("lstm-v1");
        assertThat(inference.getUpdatedAt()).isEqualTo(T2);
    }

    @Test
    void inferenceOwnershipAndVersionRules() {
        UUID mine = ownedCow();
        UUID foreign = foreignCow();
        UUID storedForeign = UUID.randomUUID();
        UUID ofForeignCow = UUID.randomUUID();
        UUID older = UUID.randomUUID();
        Inference foreignInference = new Inference(storedForeign, T1);
        foreignInference.update(foreign, DAY, 0.1, null, RiskCause.MODEL, RiskLevel.GREEN, "v", false, T1);
        when(inferences.findById(storedForeign)).thenReturn(Optional.of(foreignInference));
        Inference newer = new Inference(older, T1);
        newer.update(mine, DAY, 0.2, null, RiskCause.MODEL, RiskLevel.GREEN, "v", false, T3);
        when(inferences.findById(older)).thenReturn(Optional.of(newer));

        SyncResponse response = service.sync(OWNER, new SyncRequest(null, null, List.of(
                inferenceSync(storedForeign, mine, 0.9, null, T3),
                inferenceSync(ofForeignCow, foreign, 0.9, null, T3),
                inferenceSync(older, mine, 0.9, null, T2)), null, null));

        assertThat(response.rejected()).containsExactly(
                new Rejected("inference", storedForeign, SyncService.NOT_OWNED),
                new Rejected("inference", ofForeignCow, SyncService.COW_NOT_FOUND));
        assertThat(response.confirmed().inferences()).containsExactly(older);
        assertThat(newer.getProbability()).isEqualTo(0.2);
        verify(inferences, never()).saveAndFlush(any());
    }

    // ---- Alertas ----

    @Test
    void greenAlertIsRejected() {
        UUID cowId = ownedCow();
        UUID id = UUID.randomUUID();

        SyncResponse response = service.sync(OWNER, new SyncRequest(null, null, null,
                List.of(alertSync(id, cowId, null, RiskLevel.GREEN, T1)), null));

        assertRejected(response, "alert", id, "Una alerta solo puede ser amarilla o roja.");
        verify(alerts, never()).saveAndFlush(any());
    }

    @Test
    void alertWithoutInferenceIsStoredWithAllFields() {
        UUID cowId = ownedCow();
        UUID id = UUID.randomUUID();

        SyncResponse response = service.sync(OWNER, new SyncRequest(null, null, null,
                List.of(alertSync(id, cowId, null, RiskLevel.YELLOW, T2)), null));

        assertThat(response.confirmed().alerts()).containsExactly(id);
        ArgumentCaptor<Alert> saved = ArgumentCaptor.forClass(Alert.class);
        verify(alerts).saveAndFlush(saved.capture());
        Alert alert = saved.getValue();
        assertThat(alert.getId()).isEqualTo(id);
        assertThat(alert.getCowId()).isEqualTo(cowId);
        assertThat(alert.getInferenceId()).isNull();
        assertThat(alert.getRiskLevel()).isEqualTo(RiskLevel.YELLOW);
        assertThat(alert.isAttended()).isTrue();
        assertThat(alert.getAttendedAt()).isEqualTo(T1);
        assertThat(alert.getCreatedAt()).isEqualTo(NOW);
        assertThat(alert.getUpdatedAt()).isEqualTo(T2);
        verify(inferences, never()).findById(any());
    }

    @Test
    void alertMustPointToAnInferenceOfTheSameCow() {
        UUID cowId = ownedCow();
        UUID otherCow = ownedCow();
        UUID sameCowInference = UUID.randomUUID();
        UUID otherCowInference = UUID.randomUUID();
        Inference same = new Inference(sameCowInference, T1);
        same.update(cowId, DAY, 0.9, null, RiskCause.MODEL, RiskLevel.RED, "v", false, T1);
        Inference other = new Inference(otherCowInference, T1);
        other.update(otherCow, DAY, 0.9, null, RiskCause.MODEL, RiskLevel.RED, "v", false, T1);
        when(inferences.findById(sameCowInference)).thenReturn(Optional.of(same));
        when(inferences.findById(otherCowInference)).thenReturn(Optional.of(other));
        UUID ok = UUID.randomUUID();
        UUID wrongCow = UUID.randomUUID();
        UUID missing = UUID.randomUUID();

        SyncResponse response = service.sync(OWNER, new SyncRequest(null, null, null, List.of(
                alertSync(ok, cowId, sameCowInference, RiskLevel.RED, T1),
                alertSync(wrongCow, cowId, otherCowInference, RiskLevel.RED, T1),
                alertSync(missing, cowId, UUID.randomUUID(), RiskLevel.RED, T1)), null));

        String reason = "La inferencia de la alerta no existe para esa vaca.";
        assertThat(response.rejected()).containsExactly(new Rejected("alert", wrongCow, reason),
                new Rejected("alert", missing, reason));
        assertThat(response.confirmed().alerts()).containsExactly(ok);
    }

    @Test
    void alertOwnershipAndVersionRules() {
        UUID mine = ownedCow();
        UUID foreign = foreignCow();
        UUID storedForeign = UUID.randomUUID();
        UUID ofForeignCow = UUID.randomUUID();
        UUID older = UUID.randomUUID();
        Alert foreignAlert = new Alert(storedForeign, T1);
        foreignAlert.update(foreign, null, RiskLevel.RED, false, null, false, T1);
        when(alerts.findById(storedForeign)).thenReturn(Optional.of(foreignAlert));
        Alert newer = new Alert(older, T1);
        newer.update(mine, null, RiskLevel.RED, false, null, false, T3);
        when(alerts.findById(older)).thenReturn(Optional.of(newer));

        SyncResponse response = service.sync(OWNER, new SyncRequest(null, null, null, List.of(
                alertSync(storedForeign, mine, null, RiskLevel.RED, T3),
                alertSync(ofForeignCow, foreign, null, RiskLevel.RED, T3),
                alertSync(older, mine, null, RiskLevel.YELLOW, T2)), null));

        assertThat(response.rejected()).containsExactly(
                new Rejected("alert", storedForeign, SyncService.NOT_OWNED),
                new Rejected("alert", ofForeignCow, SyncService.COW_NOT_FOUND));
        assertThat(response.confirmed().alerts()).containsExactly(older);
        assertThat(newer.isAttended()).isFalse();
        verify(alerts, never()).saveAndFlush(any());
    }

    // ---- Fotos ----

    @Test
    void newPhotoStoresResearchDataAndKeepsTheFile() {
        UUID cowId = ownedCow();
        UUID id = UUID.randomUUID();

        SyncResponse response = service.sync(OWNER, new SyncRequest(null, null, null, null,
                List.of(photoSync(id, cowId, T2, false))));

        assertThat(response.confirmed().photos()).containsExactly(id);
        ArgumentCaptor<CowPhoto> saved = ArgumentCaptor.forClass(CowPhoto.class);
        verify(photos).saveAndFlush(saved.capture());
        CowPhoto photo = saved.getValue();
        assertThat(photo.getId()).isEqualTo(id);
        assertThat(photo.getCowId()).isEqualTo(cowId);
        assertThat(photo.getTakenOn()).isEqualTo(DAY);
        assertThat(photo.isDeleted()).isFalse();
        assertThat(photo.getUpdatedAt()).isEqualTo(T2);
        assertThat(photo.getVetConfirmed()).isEqualTo(VetConfirmation.YES);
        assertThat(photo.getDiagnosis()).isEqualTo(Diagnosis.MASTITIS);
        assertThat(photo.isResearchConsent()).isTrue();
        assertThat(photo.getResearchConsentAt()).isEqualTo(NOW);
        verify(storage, never()).delete(any());
    }

    @Test
    void deletedPhotoRemovesTheFile() {
        UUID cowId = ownedCow();
        UUID id = UUID.randomUUID();

        service.sync(OWNER, new SyncRequest(null, null, null, null, List.of(photoSync(id, cowId, T2, true))));

        verify(storage).delete(id);
    }

    @Test
    void photoOwnershipAndVersionRules() {
        UUID mine = ownedCow();
        UUID foreign = foreignCow();
        UUID storedForeign = UUID.randomUUID();
        UUID ofForeignCow = UUID.randomUUID();
        UUID older = UUID.randomUUID();
        CowPhoto foreignPhoto = new CowPhoto(storedForeign, T1);
        foreignPhoto.update(foreign, DAY, false, T1);
        when(photos.findById(storedForeign)).thenReturn(Optional.of(foreignPhoto));
        CowPhoto newer = new CowPhoto(older, T1);
        newer.update(mine, DAY, false, T3);
        when(photos.findById(older)).thenReturn(Optional.of(newer));

        SyncResponse response = service.sync(OWNER, new SyncRequest(null, null, null, null, List.of(
                photoSync(storedForeign, mine, T3, true),
                photoSync(ofForeignCow, foreign, T3, true),
                photoSync(older, mine, T2, true))));

        assertThat(response.rejected()).containsExactly(
                new Rejected("photo", storedForeign, SyncService.NOT_OWNED),
                new Rejected("photo", ofForeignCow, SyncService.COW_NOT_FOUND));
        assertThat(response.confirmed().photos()).containsExactly(older);
        // La versión vieja no borra nada: ni el registro ni el archivo
        assertThat(newer.isDeleted()).isFalse();
        verify(photos, never()).saveAndFlush(any());
        verify(storage, never()).delete(any());
    }

    @Test
    void newerVersionsOfStoredChildrenReplaceThem() {
        UUID cowId = ownedCow();
        UUID recordId = UUID.randomUUID();
        UUID inferenceId = UUID.randomUUID();
        UUID alertId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        DailyRecord record = new DailyRecord(recordId, T1);
        record.update(cowId, DAY, 38.0, 10.0, 9.0, Symptoms.NONE, ValueSources.NONE, "viejo", false, T1);
        Inference inference = new Inference(inferenceId, T1);
        inference.update(cowId, DAY, 0.1, null, RiskCause.MODEL, RiskLevel.GREEN, "v0", false, T1);
        Alert alert = new Alert(alertId, T1);
        alert.update(cowId, null, RiskLevel.YELLOW, false, null, false, T1);
        CowPhoto photo = new CowPhoto(photoId, T1);
        photo.update(cowId, DAY.minusDays(1), false, T1);
        when(records.findById(recordId)).thenReturn(Optional.of(record));
        when(inferences.findById(inferenceId)).thenReturn(Optional.of(inference));
        when(alerts.findById(alertId)).thenReturn(Optional.of(alert));
        when(photos.findById(photoId)).thenReturn(Optional.of(photo));

        SyncResponse response = service.sync(OWNER, new SyncRequest(null,
                List.of(recordSync(recordId, cowId, T2, false)),
                List.of(inferenceSync(inferenceId, cowId, 0.95, null, T2)),
                List.of(alertSync(alertId, cowId, null, RiskLevel.RED, T2)),
                List.of(photoSync(photoId, cowId, T2, false))));

        assertThat(response.rejected()).isEmpty();
        assertThat(record.getNotes()).isEqualTo("Revisar");
        assertThat(inference.getProbability()).isEqualTo(0.95);
        assertThat(alert.getRiskLevel()).isEqualTo(RiskLevel.RED);
        assertThat(photo.getTakenOn()).isEqualTo(DAY);
        verify(records).saveAndFlush(record);
        verify(inferences).saveAndFlush(inference);
        verify(alerts).saveAndFlush(alert);
        verify(photos).saveAndFlush(photo);
    }

    @Test
    void emptyBatchConfirmsNothing() {
        SyncResponse response = service.sync(OWNER, new SyncRequest(null, null, null, null, null));

        assertThat(response.confirmed().cows()).isEmpty();
        assertThat(response.confirmed().dailyRecords()).isEmpty();
        assertThat(response.confirmed().inferences()).isEmpty();
        assertThat(response.confirmed().alerts()).isEmpty();
        assertThat(response.confirmed().photos()).isEmpty();
        assertThat(response.rejected()).isEmpty();
        assertThat(response.serverTime()).isEqualTo(NOW);
    }
}
