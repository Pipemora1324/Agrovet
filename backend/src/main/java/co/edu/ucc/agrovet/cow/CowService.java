package co.edu.ucc.agrovet.cow;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import co.edu.ucc.agrovet.alert.AlertRepository;
import co.edu.ucc.agrovet.common.BadRequestException;
import co.edu.ucc.agrovet.common.ConflictException;
import co.edu.ucc.agrovet.common.NotFoundException;
import co.edu.ucc.agrovet.cow.CowDtos.AlertResponse;
import co.edu.ucc.agrovet.cow.CowDtos.CowRequest;
import co.edu.ucc.agrovet.cow.CowDtos.CowResponse;
import co.edu.ucc.agrovet.cow.CowDtos.DailyRecordResponse;
import co.edu.ucc.agrovet.cow.CowDtos.HistoryResponse;
import co.edu.ucc.agrovet.cow.CowDtos.InferenceResponse;
import co.edu.ucc.agrovet.inference.InferenceRepository;
import co.edu.ucc.agrovet.record.DailyRecordRepository;

@Service
public class CowService {

    static final String COW_NOT_FOUND = "La vaca no existe.";
    static final int DEFAULT_HISTORY_DAYS = 60;
    static final int MAX_HISTORY_DAYS = 366;

    private final CowRepository cows;
    private final DailyRecordRepository records;
    private final InferenceRepository inferences;
    private final AlertRepository alerts;
    private final Clock clock;

    public CowService(CowRepository cows, DailyRecordRepository records, InferenceRepository inferences,
            AlertRepository alerts, Clock clock) {
        this.cows = cows;
        this.records = records;
        this.inferences = inferences;
        this.alerts = alerts;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<CowResponse> list(UUID ownerId) {
        return cows.findAllByOwnerIdAndDeletedFalseOrderByTagAsc(ownerId).stream().map(CowResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public CowResponse get(UUID ownerId, UUID cowId) {
        return CowResponse.from(findOwned(ownerId, cowId));
    }

    @Transactional
    public CowResponse create(UUID ownerId, CowRequest request) {
        UUID id = request.id() != null ? request.id() : UUID.randomUUID();
        if (cows.existsById(id)) {
            throw new ConflictException("Ya existe una vaca con ese id.");
        }
        Instant now = clock.instant();
        Cow cow = new Cow(id, ownerId, now);
        apply(cow, ownerId, request, now);
        return CowResponse.from(cows.save(cow));
    }

    @Transactional
    public CowResponse update(UUID ownerId, UUID cowId, CowRequest request) {
        Cow cow = findOwned(ownerId, cowId);
        apply(cow, ownerId, request, clock.instant());
        return CowResponse.from(cow);
    }

    @Transactional
    public void delete(UUID ownerId, UUID cowId) {
        findOwned(ownerId, cowId).setDeleted(true, clock.instant());
    }

    @Transactional(readOnly = true)
    public HistoryResponse history(UUID ownerId, UUID cowId, LocalDate from, LocalDate to) {
        Cow cow = findOwned(ownerId, cowId);
        LocalDate end = to != null ? to : LocalDate.now(clock);
        LocalDate start = from != null ? from : end.minusDays(DEFAULT_HISTORY_DAYS - 1);
        if (start.isAfter(end)) {
            throw new BadRequestException("La fecha inicial no puede ser posterior a la final.");
        }
        if (ChronoUnit.DAYS.between(start, end) >= MAX_HISTORY_DAYS) {
            throw new BadRequestException("El rango máximo del historial es de " + MAX_HISTORY_DAYS + " días.");
        }
        return new HistoryResponse(CowResponse.from(cow), start, end,
                records.findAllByCowIdAndDeletedFalseAndRecordDateBetweenOrderByRecordDateAsc(cowId, start, end)
                        .stream().map(DailyRecordResponse::from).toList(),
                inferences.findAllByCowIdAndDeletedFalseAndWindowEndDateBetweenOrderByWindowEndDateAsc(cowId, start,
                        end).stream().map(InferenceResponse::from).toList(),
                alerts.findAllByCowIdAndDeletedFalseOrderByCreatedAtDesc(cowId).stream()
                        .map(AlertResponse::from).toList());
    }

    /** Las vacas de otro usuario se tratan como inexistentes (404) para no revelar ids. */
    private Cow findOwned(UUID ownerId, UUID cowId) {
        return cows.findByIdAndOwnerIdAndDeletedFalse(cowId, ownerId)
                .orElseThrow(() -> new NotFoundException(COW_NOT_FOUND));
    }

    private void apply(Cow cow, UUID ownerId, CowRequest request, Instant now) {
        String tag = request.tag().trim();
        if (cows.existsByOwnerIdAndTagAndDeletedFalseAndIdNot(ownerId, tag, cow.getId())) {
            throw new ConflictException("Ya tiene otra vaca con el identificador " + tag + ".");
        }
        cow.update(tag, blankToNull(request.name()), blankToNull(request.breed()), request.birthDate(),
                request.calvings(), request.productionStatus(), now);
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
