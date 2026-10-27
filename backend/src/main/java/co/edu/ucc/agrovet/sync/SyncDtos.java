package co.edu.ucc.agrovet.sync;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import co.edu.ucc.agrovet.cow.ProductionStatus;
import co.edu.ucc.agrovet.inference.RiskLevel;

public final class SyncDtos {

    static final int MAX_ITEMS = 500;

    private SyncDtos() {
    }

    /** Lote enviado por la app. Cada elemento lleva su UUID y la hora de su última modificación. */
    public record SyncRequest(
            @Size(max = MAX_ITEMS, message = "Máximo 500 vacas por lote.")
            List<@Valid @NotNull CowSync> cows,
            @Size(max = MAX_ITEMS, message = "Máximo 500 registros diarios por lote.")
            List<@Valid @NotNull DailyRecordSync> dailyRecords,
            @Size(max = MAX_ITEMS, message = "Máximo 500 inferencias por lote.")
            List<@Valid @NotNull InferenceSync> inferences,
            @Size(max = MAX_ITEMS, message = "Máximo 500 alertas por lote.")
            List<@Valid @NotNull AlertSync> alerts) {

        public SyncRequest {
            cows = cows == null ? List.of() : cows;
            dailyRecords = dailyRecords == null ? List.of() : dailyRecords;
            inferences = inferences == null ? List.of() : inferences;
            alerts = alerts == null ? List.of() : alerts;
        }
    }

    public record CowSync(
            @NotNull(message = "Falta el id.") UUID id,
            @NotBlank(message = "El identificador de la vaca es obligatorio.")
            @Size(max = 40, message = "El identificador admite máximo 40 caracteres.") String tag,
            @Size(max = 80) String name,
            @Size(max = 60) String breed,
            LocalDate birthDate,
            @Min(0) @Max(30) Integer calvings,
            @NotNull(message = "El estado productivo es obligatorio.") ProductionStatus productionStatus,
            @NotNull(message = "Falta la fecha de modificación.") Instant updatedAt,
            boolean deleted) {
    }

    public record DailyRecordSync(
            @NotNull(message = "Falta el id.") UUID id,
            @NotNull(message = "Falta la vaca.") UUID cowId,
            @NotNull(message = "Falta la fecha del registro.") LocalDate recordDate,
            @DecimalMin(value = "30", message = "Temperatura fuera de rango.")
            @DecimalMax(value = "45", message = "Temperatura fuera de rango.") Double temperatureC,
            @DecimalMin(value = "0", message = "Leche fuera de rango.")
            @DecimalMax(value = "80", message = "Leche fuera de rango.") Double milkL,
            @DecimalMin(value = "0", message = "Alimento fuera de rango.")
            @DecimalMax(value = "60", message = "Alimento fuera de rango.") Double feedKg,
            boolean udderSwelling,
            boolean abnormalMilk,
            boolean udderPain,
            boolean lethargy,
            @Size(max = 500, message = "Las notas admiten máximo 500 caracteres.") String notes,
            @NotNull(message = "Falta la fecha de modificación.") Instant updatedAt,
            boolean deleted) {
    }

    public record InferenceSync(
            @NotNull(message = "Falta el id.") UUID id,
            @NotNull(message = "Falta la vaca.") UUID cowId,
            @NotNull(message = "Falta la fecha de la ventana.") LocalDate windowEndDate,
            @NotNull @DecimalMin(value = "0", message = "Probabilidad fuera de rango.")
            @DecimalMax(value = "1", message = "Probabilidad fuera de rango.") Double probability,
            @NotNull(message = "Falta el color del semáforo.") RiskLevel riskLevel,
            @NotBlank @Size(max = 40) String modelVersion,
            @NotNull(message = "Falta la fecha de modificación.") Instant updatedAt,
            boolean deleted) {
    }

    public record AlertSync(
            @NotNull(message = "Falta el id.") UUID id,
            @NotNull(message = "Falta la vaca.") UUID cowId,
            UUID inferenceId,
            @NotNull(message = "Falta el nivel de la alerta.") RiskLevel riskLevel,
            boolean attended,
            Instant attendedAt,
            @NotNull(message = "Falta la fecha de modificación.") Instant updatedAt,
            boolean deleted) {
    }

    public record Rejected(String entity, UUID id, String reason) {
    }

    public record Confirmed(List<UUID> cows, List<UUID> dailyRecords, List<UUID> inferences, List<UUID> alerts) {
    }

    /** confirmed: guardados o ya presentes en una versión igual o más reciente. rejected: no se guardaron. */
    public record SyncResponse(Confirmed confirmed, List<Rejected> rejected, Instant serverTime) {
    }
}
