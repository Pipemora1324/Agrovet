package co.edu.ucc.agrovet.cow;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;

import co.edu.ucc.agrovet.alert.Alert;
import co.edu.ucc.agrovet.inference.Inference;
import co.edu.ucc.agrovet.inference.RiskLevel;
import co.edu.ucc.agrovet.record.DailyRecord;
import co.edu.ucc.agrovet.record.Symptoms;

public final class CowDtos {

    private CowDtos() {
    }

    /** El id es opcional: la app lo envía (UUID generado en el celular); si falta, lo genera el servidor. */
    public record CowRequest(
            UUID id,
            @NotBlank(message = "El identificador de la vaca es obligatorio.")
            @Size(max = 40, message = "El identificador admite máximo 40 caracteres.")
            String tag,
            @Size(max = 80, message = "El nombre admite máximo 80 caracteres.")
            String name,
            @Size(max = 60, message = "La raza admite máximo 60 caracteres.")
            String breed,
            @PastOrPresent(message = "La fecha de nacimiento no puede ser futura.")
            LocalDate birthDate,
            @Min(value = 0, message = "El número de partos no puede ser negativo.")
            @Max(value = 30, message = "El número de partos no es válido.")
            Integer calvings,
            @NotNull(message = "El estado productivo es obligatorio.")
            ProductionStatus productionStatus) {
    }

    public record CowResponse(UUID id, String tag, String name, String breed, LocalDate birthDate,
            Integer calvings, ProductionStatus productionStatus, Instant updatedAt) {

        public static CowResponse from(Cow cow) {
            return new CowResponse(cow.getId(), cow.getTag(), cow.getName(), cow.getBreed(), cow.getBirthDate(),
                    cow.getCalvings(), cow.getProductionStatus(), cow.getUpdatedAt());
        }
    }

    public record DailyRecordResponse(UUID id, LocalDate recordDate, Double temperatureC, Double milkL,
            Double feedKg, Symptoms symptoms, String notes) {

        public static DailyRecordResponse from(DailyRecord record) {
            return new DailyRecordResponse(record.getId(), record.getRecordDate(), record.getTemperatureC(),
                    record.getMilkL(), record.getFeedKg(), record.getSymptoms(), record.getNotes());
        }
    }

    public record InferenceResponse(UUID id, LocalDate windowEndDate, double probability, RiskLevel riskLevel,
            String modelVersion) {

        public static InferenceResponse from(Inference inference) {
            return new InferenceResponse(inference.getId(), inference.getWindowEndDate(), inference.getProbability(),
                    inference.getRiskLevel(), inference.getModelVersion());
        }
    }

    public record AlertResponse(UUID id, UUID inferenceId, RiskLevel riskLevel, boolean attended,
            Instant attendedAt, Instant createdAt) {

        public static AlertResponse from(Alert alert) {
            return new AlertResponse(alert.getId(), alert.getInferenceId(), alert.getRiskLevel(), alert.isAttended(),
                    alert.getAttendedAt(), alert.getCreatedAt());
        }
    }

    public record HistoryResponse(CowResponse cow, LocalDate from, LocalDate to, List<DailyRecordResponse> records,
            List<InferenceResponse> inferences, List<AlertResponse> alerts) {
    }
}
