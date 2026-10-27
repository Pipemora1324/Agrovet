package co.edu.ucc.agrovet.cow;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import co.edu.ucc.agrovet.common.CurrentUser;
import co.edu.ucc.agrovet.cow.CowDtos.CowRequest;
import co.edu.ucc.agrovet.cow.CowDtos.CowResponse;
import co.edu.ucc.agrovet.cow.CowDtos.HistoryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/cows")
@Tag(name = "Vacas")
@SecurityRequirement(name = "bearer")
public class CowController {

    private final CowService cowService;

    public CowController(CowService cowService) {
        this.cowService = cowService;
    }

    @GetMapping
    @Operation(summary = "Lista las vacas activas del usuario")
    public List<CowResponse> list(@AuthenticationPrincipal Jwt jwt) {
        return cowService.list(CurrentUser.id(jwt));
    }

    @GetMapping("/{id}")
    public CowResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return cowService.get(CurrentUser.id(jwt), id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CowResponse create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody CowRequest request) {
        return cowService.create(CurrentUser.id(jwt), request);
    }

    @PutMapping("/{id}")
    public CowResponse update(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody CowRequest request) {
        return cowService.update(CurrentUser.id(jwt), id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Da de baja la vaca (borrado lógico)")
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        cowService.delete(CurrentUser.id(jwt), id);
    }

    @GetMapping("/{id}/history")
    @Operation(summary = "Registros, inferencias y alertas de la vaca en un rango de fechas (por defecto, 60 días)")
    public HistoryResponse history(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return cowService.history(CurrentUser.id(jwt), id, from, to);
    }
}
