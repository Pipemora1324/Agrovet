package co.edu.ucc.agrovet.auth;

import java.util.UUID;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import co.edu.ucc.agrovet.auth.AuthDtos.LoginRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.RefreshRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.RegisterRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.TokenResponse;
import co.edu.ucc.agrovet.auth.AuthDtos.UserResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Autenticación")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Crea una cuenta y devuelve los tokens de sesión")
    public TokenResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    @Operation(summary = "Inicia sesión (con límite de intentos)")
    public TokenResponse login(@Valid @RequestBody LoginRequest request, HttpServletRequest http) {
        // Se usa la IP de la conexión; detrás de un proxy hay que configurar forward-headers-strategy
        return authService.login(request, http.getRemoteAddr());
    }

    @PostMapping("/refresh")
    @Operation(summary = "Renueva la sesión; el refresh token usado deja de servir")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return authService.refresh(request.refreshToken());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Cierra la sesión revocando sus refresh tokens")
    public void logout(@Valid @RequestBody RefreshRequest request) {
        authService.logout(request.refreshToken());
    }

    @GetMapping("/me")
    @SecurityRequirement(name = "bearer")
    @Operation(summary = "Datos del usuario autenticado")
    public UserResponse me(@AuthenticationPrincipal Jwt jwt) {
        return authService.currentUser(UUID.fromString(jwt.getSubject()));
    }
}
