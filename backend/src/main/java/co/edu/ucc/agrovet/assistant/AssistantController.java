package co.edu.ucc.agrovet.assistant;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import co.edu.ucc.agrovet.assistant.AssistantDtos.ChatRequest;
import co.edu.ucc.agrovet.assistant.AssistantDtos.ChatResponse;
import co.edu.ucc.agrovet.common.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/assistant")
@Tag(name = "Asistente")
@SecurityRequirement(name = "bearer")
public class AssistantController {

    private final AssistantService assistant;

    public AssistantController(AssistantService assistant) {
        this.assistant = assistant;
    }

    @PostMapping("/chat")
    @Operation(summary = "Pregunta al asistente de IA (orienta, no diagnostica)",
            description = "Con límite por usuario. 503 si el proveedor no está configurado o no responde.")
    public ChatResponse chat(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ChatRequest request) {
        return assistant.chat(CurrentUser.id(jwt), request);
    }

    @ExceptionHandler(AssistantUnavailableException.class)
    ProblemDetail handleUnavailable(AssistantUnavailableException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE, ex.userMessage());
        problem.setTitle("Asistente no disponible");
        return problem;
    }
}
