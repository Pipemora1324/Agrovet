package co.edu.ucc.agrovet.auth;

import java.time.Instant;
import java.util.UUID;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import co.edu.ucc.agrovet.user.User;

public final class AuthDtos {

    private AuthDtos() {
    }

    public record RegisterRequest(
            @NotBlank(message = "El nombre es obligatorio.")
            @Size(max = 100, message = "El nombre admite máximo 100 caracteres.")
            String name,
            @NotBlank(message = "El correo es obligatorio.")
            @Email(message = "El correo no es válido.")
            @Size(max = 254, message = "El correo es demasiado largo.")
            String email,
            // BCrypt solo considera los primeros 72 bytes
            @NotBlank(message = "La contraseña es obligatoria.")
            @Size(min = 8, max = 72, message = "La contraseña debe tener entre 8 y 72 caracteres.")
            String password,
            // Ley 1581 de 2012: autorización previa, expresa e informada
            @NotNull(message = "Debe aceptar el aviso de privacidad para crear la cuenta.")
            @AssertTrue(message = "Debe aceptar el aviso de privacidad para crear la cuenta.")
            Boolean acceptPrivacyPolicy,
            @NotBlank(message = "Falta la versión del aviso de privacidad.")
            @Size(max = 20, message = "La versión del aviso de privacidad no es válida.")
            String privacyPolicyVersion) {
    }

    public record UpdateProfileRequest(
            @NotBlank(message = "El nombre es obligatorio.")
            @Size(max = 100, message = "El nombre admite máximo 100 caracteres.")
            String name,
            @Size(max = 100, message = "El nombre de la finca admite máximo 100 caracteres.")
            String farmName,
            @Size(max = 80, message = "El municipio admite máximo 80 caracteres.")
            String municipality,
            @Pattern(regexp = "^$|^\\+?[0-9][0-9 ]{6,18}$",
                    message = "Escriba el teléfono solo con números (por ejemplo, 3001234567).")
            String phone) {
    }

    public record ChangePasswordRequest(
            @NotBlank(message = "Escriba su contraseña actual.")
            @Size(max = 72, message = "La contraseña es demasiado larga.")
            String currentPassword,
            @NotBlank(message = "La contraseña es obligatoria.")
            @Size(min = 8, max = 72, message = "La contraseña debe tener entre 8 y 72 caracteres.")
            String newPassword) {
    }

    /** Eliminar la cuenta exige la contraseña, aunque la sesión esté abierta. */
    public record DeleteAccountRequest(
            @NotBlank(message = "Escriba su contraseña para confirmar.")
            @Size(max = 72, message = "La contraseña es demasiado larga.")
            String password) {
    }

    /** Para aceptar el aviso de privacidad después del registro (cuentas anteriores o versión nueva). */
    public record AcceptPrivacyRequest(
            @NotBlank(message = "Falta la versión del aviso de privacidad.")
            @Size(max = 20, message = "La versión del aviso de privacidad no es válida.")
            String privacyPolicyVersion) {
    }

    public record LoginRequest(
            @NotBlank(message = "El correo es obligatorio.")
            @Email(message = "El correo no es válido.")
            @Size(max = 254, message = "El correo es demasiado largo.")
            String email,
            @NotBlank(message = "La contraseña es obligatoria.")
            @Size(max = 72, message = "La contraseña es demasiado larga.")
            String password) {
    }

    public record RefreshRequest(
            @NotBlank(message = "Falta el refresh token.")
            @Size(max = 200, message = "El refresh token no es válido.")
            String refreshToken) {
    }

    /** Solo el correo: reenviar el código o pedir uno para cambiar la contraseña. */
    public record EmailRequest(
            @NotBlank(message = "El correo es obligatorio.")
            @Email(message = "El correo no es válido.")
            @Size(max = 254, message = "El correo es demasiado largo.")
            String email) {
    }

    public record VerifyEmailRequest(
            @NotBlank(message = "El correo es obligatorio.")
            @Email(message = "El correo no es válido.")
            @Size(max = 254, message = "El correo es demasiado largo.")
            String email,
            @NotBlank(message = "Escriba el código.")
            @Pattern(regexp = "\\d{6}", message = "El código tiene 6 números.")
            String code) {
    }

    public record ResetPasswordRequest(
            @NotBlank(message = "El correo es obligatorio.")
            @Email(message = "El correo no es válido.")
            @Size(max = 254, message = "El correo es demasiado largo.")
            String email,
            @NotBlank(message = "Escriba el código.")
            @Pattern(regexp = "\\d{6}", message = "El código tiene 6 números.")
            String code,
            @NotBlank(message = "La contraseña es obligatoria.")
            @Size(min = 8, max = 72, message = "La contraseña debe tener entre 8 y 72 caracteres.")
            String newPassword) {
    }

    /** Respuesta que no revela si el correo está registrado. */
    public record MessageResponse(String message) {
    }

    public record UserResponse(UUID id, String name, String email, String farmName, String municipality,
            String phone, String privacyPolicyVersion, Instant privacyAcceptedAt) {

        static UserResponse from(User user) {
            return new UserResponse(user.getId(), user.getName(), user.getEmail(), user.getFarmName(),
                    user.getMunicipality(), user.getPhone(), user.getPrivacyPolicyVersion(),
                    user.getPrivacyAcceptedAt());
        }
    }

    public record TokenResponse(String accessToken, String refreshToken, String tokenType, long expiresIn,
            UserResponse user) {
    }
}
