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

import co.edu.ucc.agrovet.auth.AuthDtos.EmailRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.LoginRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.MessageResponse;
import co.edu.ucc.agrovet.auth.AuthDtos.RefreshRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.RegisterRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.ResetPasswordRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.TokenResponse;
import co.edu.ucc.agrovet.auth.AuthDtos.UserResponse;
import co.edu.ucc.agrovet.auth.AuthDtos.VerifyEmailRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

/** La IP es la de la conexión; detrás de un proxy hay que configurar forward-headers-strategy. */
@RestController
@RequestMapping("/api/auth")
@Tag(name = "Autenticación")
public class AuthController {

    private static final MessageResponse CODE_SENT = new MessageResponse(AuthService.CODE_SENT);

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @Operation(summary = "Crea la cuenta sin verificar y envía un código al correo",
            description = "La respuesta es la misma si el correo ya estaba registrado.")
    public MessageResponse register(@Valid @RequestBody RegisterRequest request, HttpServletRequest http) {
        authService.register(request, http.getRemoteAddr());
        return CODE_SENT;
    }

    @PostMapping("/verify-email")
    @Operation(summary = "Verifica el correo con el código de 6 números y abre la sesión")
    public TokenResponse verifyEmail(@Valid @RequestBody VerifyEmailRequest request) {
        return authService.verifyEmail(request);
    }

    @PostMapping("/resend-code")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @Operation(summary = "Envía un código nuevo para verificar el correo (con espera entre envíos)")
    public MessageResponse resendCode(@Valid @RequestBody EmailRequest request, HttpServletRequest http) {
        authService.resendVerificationCode(request.email(), http.getRemoteAddr());
        return CODE_SENT;
    }

    @PostMapping("/login")
    @Operation(summary = "Inicia sesión (con límite de intentos)",
            description = "Si el correo no está verificado responde 403 con code = EMAIL_NOT_VERIFIED.")
    public TokenResponse login(@Valid @RequestBody LoginRequest request, HttpServletRequest http) {
        return authService.login(request, http.getRemoteAddr());
    }

    @PostMapping("/password/forgot")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @Operation(summary = "Envía un código para crear una contraseña nueva")
    public MessageResponse forgotPassword(@Valid @RequestBody EmailRequest request, HttpServletRequest http) {
        authService.requestPasswordReset(request.email(), http.getRemoteAddr());
        return CODE_SENT;
    }

    @PostMapping("/password/reset")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Cambia la contraseña con el código y cierra todas las sesiones")
    public void resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request);
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
