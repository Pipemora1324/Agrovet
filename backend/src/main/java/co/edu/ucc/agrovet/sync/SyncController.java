package co.edu.ucc.agrovet.sync;

import jakarta.validation.Valid;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import co.edu.ucc.agrovet.common.CurrentUser;
import co.edu.ucc.agrovet.sync.SyncDtos.SyncRequest;
import co.edu.ucc.agrovet.sync.SyncDtos.SyncResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/sync")
@Tag(name = "Sincronización")
@SecurityRequirement(name = "bearer")
public class SyncController {

    private final SyncService syncService;

    public SyncController(SyncService syncService) {
        this.syncService = syncService;
    }

    @PostMapping
    @Operation(summary = "Recibe un lote de cambios del celular (idempotente, upsert por UUID)")
    public SyncResponse sync(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SyncRequest request) {
        return syncService.sync(CurrentUser.id(jwt), request);
    }
}
