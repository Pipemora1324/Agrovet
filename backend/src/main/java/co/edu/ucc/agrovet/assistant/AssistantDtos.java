package co.edu.ucc.agrovet.assistant;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import co.edu.ucc.agrovet.inference.RiskCause;
import co.edu.ucc.agrovet.inference.RiskLevel;

public final class AssistantDtos {

    private AssistantDtos() {
    }

    /** Contexto mínimo de la vaca: lo que la app ya calculó. No lleva nombre ni datos de la persona. */
    public record CowContext(
            RiskLevel riskLevel,
            RiskCause cause,
            @Min(0) @Max(30) Integer symptomScore,
            @DecimalMin("0") @DecimalMax("1") Double probability,
            @Size(max = 12, message = "Demasiados síntomas.")
            List<@NotBlank @Size(max = 60) String> symptoms) {
    }

    public record HistoryTurn(
            boolean fromUser,
            @NotBlank @Size(max = 2000, message = "Un mensaje anterior es demasiado largo.") String text) {
    }

    public record ChatRequest(
            @NotBlank(message = "Escriba su pregunta.")
            @Size(max = 1000, message = "La pregunta admite máximo 1000 caracteres.")
            String question,
            @Valid CowContext context,
            // Solo los últimos turnos, para dar continuidad sin enviar toda la conversación
            @Size(max = 6, message = "Se envían como máximo 6 mensajes anteriores.")
            List<@Valid @NotNull HistoryTurn> history,
            // Foto en Base64 (JPEG o PNG). ~6,7 MB de texto = 5 MB de imagen
            @Size(max = 6_990_000, message = "La foto pesa demasiado.")
            String photoBase64) {

        public ChatRequest {
            history = history == null ? List.of() : history;
        }
    }

    public record ChatResponse(String answer) {
    }
}
