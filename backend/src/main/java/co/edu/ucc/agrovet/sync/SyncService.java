package co.edu.ucc.agrovet.sync;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import co.edu.ucc.agrovet.alert.Alert;
import co.edu.ucc.agrovet.alert.AlertRepository;
import co.edu.ucc.agrovet.cow.Cow;
import co.edu.ucc.agrovet.cow.CowRepository;
import co.edu.ucc.agrovet.inference.Inference;
import co.edu.ucc.agrovet.inference.InferenceRepository;
import co.edu.ucc.agrovet.inference.RiskLevel;
import co.edu.ucc.agrovet.record.DailyRecord;
import co.edu.ucc.agrovet.record.DailyRecordRepository;
import co.edu.ucc.agrovet.record.Symptoms;
import co.edu.ucc.agrovet.sync.SyncDtos.AlertSync;
import co.edu.ucc.agrovet.sync.SyncDtos.Confirmed;
import co.edu.ucc.agrovet.sync.SyncDtos.CowSync;
import co.edu.ucc.agrovet.sync.SyncDtos.DailyRecordSync;
import co.edu.ucc.agrovet.sync.SyncDtos.InferenceSync;
import co.edu.ucc.agrovet.sync.SyncDtos.Rejected;
import co.edu.ucc.agrovet.sync.SyncDtos.SyncRequest;
import co.edu.ucc.agrovet.sync.SyncDtos.SyncResponse;

/**
 * Recibe lotes de la app y hace upsert por UUID.
 * <ul>
 * <li>Idempotente: reenviar el mismo lote no crea duplicados.</li>
 * <li>Gana la última modificación: si el servidor ya tiene una versión más reciente
 * (updatedAt mayor), se conserva y el elemento igual se confirma.</li>
 * <li>Nada de otro usuario se puede leer ni sobrescribir: esos elementos se rechazan.</li>
 * </ul>
 * Las vacas se procesan primero para que los registros del mismo lote puedan referirse a ellas.
 */
@Service
public class SyncService {

    static final String NOT_OWNED = "El elemento pertenece a otro usuario.";
    static final String COW_NOT_FOUND = "La vaca no existe o no pertenece al usuario.";

    private final CowRepository cows;
    private final DailyRecordRepository records;
    private final InferenceRepository inferences;
    private final AlertRepository alerts;
    private final Clock clock;

    public SyncService(CowRepository cows, DailyRecordRepository records, InferenceRepository inferences,
            AlertRepository alerts, Clock clock) {
        this.cows = cows;
        this.records = records;
        this.inferences = inferences;
        this.alerts = alerts;
        this.clock = clock;
    }

    @Transactional
    public SyncResponse sync(UUID ownerId, SyncRequest request) {
        Batch batch = new Batch(ownerId);
        request.cows().forEach(item -> syncCow(batch, item));
        request.dailyRecords().forEach(item -> syncDailyRecord(batch, item));
        request.inferences().forEach(item -> syncInference(batch, item));
        request.alerts().forEach(item -> syncAlert(batch, item));
        return new SyncResponse(new Confirmed(batch.cows, batch.records, batch.inferences, batch.alerts),
                batch.rejected, clock.instant());
    }

    private void syncCow(Batch batch, CowSync item) {
        Optional<Cow> existing = cows.findById(item.id());
        if (existing.isPresent() && !existing.get().isOwnedBy(batch.ownerId)) {
            batch.reject("cow", item.id(), NOT_OWNED);
            return;
        }
        String tag = item.tag().trim();
        if (!item.deleted() && cows.existsByOwnerIdAndTagAndDeletedFalseAndIdNot(batch.ownerId, tag, item.id())) {
            batch.reject("cow", item.id(), "Ya existe otra vaca activa con el identificador " + tag + ".");
            return;
        }
        Cow cow = existing.orElseGet(() -> new Cow(item.id(), batch.ownerId, clock.instant()));
        if (existing.isEmpty() || isNewer(item.updatedAt(), cow.getUpdatedAt())) {
            cow.update(tag, item.name(), item.breed(), item.birthDate(), item.calvings(), item.productionStatus(),
                    item.updatedAt());
            cow.setDeleted(item.deleted(), item.updatedAt());
            cows.saveAndFlush(cow);
        }
        batch.ownedCows.put(cow.getId(), true);
        batch.cows.add(item.id());
    }

    private void syncDailyRecord(Batch batch, DailyRecordSync item) {
        Optional<DailyRecord> existing = records.findById(item.id());
        if (existing.isPresent() && !batch.owns(existing.get().getCowId())) {
            batch.reject("dailyRecord", item.id(), NOT_OWNED);
            return;
        }
        if (!batch.owns(item.cowId())) {
            batch.reject("dailyRecord", item.id(), COW_NOT_FOUND);
            return;
        }
        if (!item.deleted() && records.existsByCowIdAndRecordDateAndDeletedFalseAndIdNot(item.cowId(),
                item.recordDate(), item.id())) {
            batch.reject("dailyRecord", item.id(), "Ya existe otro registro de esa vaca para ese día.");
            return;
        }
        DailyRecord record = existing.orElseGet(() -> new DailyRecord(item.id(), clock.instant()));
        if (existing.isEmpty() || isNewer(item.updatedAt(), record.getUpdatedAt())) {
            record.update(item.cowId(), item.recordDate(), item.temperatureC(), item.milkL(), item.feedKg(),
                    new Symptoms(item.udderSwelling(), item.abnormalMilk(), item.udderPain(), item.lethargy()),
                    item.notes(), item.deleted(), item.updatedAt());
            records.saveAndFlush(record);
        }
        batch.records.add(item.id());
    }

    private void syncInference(Batch batch, InferenceSync item) {
        Optional<Inference> existing = inferences.findById(item.id());
        if (existing.isPresent() && !batch.owns(existing.get().getCowId())) {
            batch.reject("inference", item.id(), NOT_OWNED);
            return;
        }
        if (!batch.owns(item.cowId())) {
            batch.reject("inference", item.id(), COW_NOT_FOUND);
            return;
        }
        Inference inference = existing.orElseGet(() -> new Inference(item.id(), clock.instant()));
        if (existing.isEmpty() || isNewer(item.updatedAt(), inference.getUpdatedAt())) {
            inference.update(item.cowId(), item.windowEndDate(), item.probability(), item.riskLevel(),
                    item.modelVersion(), item.deleted(), item.updatedAt());
            inferences.saveAndFlush(inference);
        }
        batch.inferences.add(item.id());
    }

    private void syncAlert(Batch batch, AlertSync item) {
        Optional<Alert> existing = alerts.findById(item.id());
        if (existing.isPresent() && !batch.owns(existing.get().getCowId())) {
            batch.reject("alert", item.id(), NOT_OWNED);
            return;
        }
        if (!batch.owns(item.cowId())) {
            batch.reject("alert", item.id(), COW_NOT_FOUND);
            return;
        }
        if (item.riskLevel() == RiskLevel.GREEN) {
            batch.reject("alert", item.id(), "Una alerta solo puede ser amarilla o roja.");
            return;
        }
        if (item.inferenceId() != null && inferences.findById(item.inferenceId())
                .filter(inference -> inference.getCowId().equals(item.cowId())).isEmpty()) {
            batch.reject("alert", item.id(), "La inferencia de la alerta no existe para esa vaca.");
            return;
        }
        Alert alert = existing.orElseGet(() -> new Alert(item.id(), clock.instant()));
        if (existing.isEmpty() || isNewer(item.updatedAt(), alert.getUpdatedAt())) {
            alert.update(item.cowId(), item.inferenceId(), item.riskLevel(), item.attended(), item.attendedAt(),
                    item.deleted(), item.updatedAt());
            alerts.saveAndFlush(alert);
        }
        batch.alerts.add(item.id());
    }

    /** Se aplica si la versión entrante es igual o más reciente (reenviar la misma versión no cambia nada). */
    private static boolean isNewer(Instant incoming, Instant stored) {
        return !incoming.isBefore(stored);
    }

    private final class Batch {
        private final UUID ownerId;
        private final Map<UUID, Boolean> ownedCows = new HashMap<>();
        private final List<UUID> cows = new ArrayList<>();
        private final List<UUID> records = new ArrayList<>();
        private final List<UUID> inferences = new ArrayList<>();
        private final List<UUID> alerts = new ArrayList<>();
        private final List<Rejected> rejected = new ArrayList<>();

        Batch(UUID ownerId) {
            this.ownerId = ownerId;
        }

        boolean owns(UUID cowId) {
            return ownedCows.computeIfAbsent(cowId,
                    id -> SyncService.this.cows.findById(id).map(c -> c.isOwnedBy(ownerId)).orElse(false));
        }

        void reject(String entity, UUID id, String reason) {
            rejected.add(new Rejected(entity, id, reason));
        }
    }
}
