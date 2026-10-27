package co.edu.ucc.agrovet.auth;

import java.util.UUID;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
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
            String password) {
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

    public record UserResponse(UUID id, String name, String email) {

        static UserResponse from(User user) {
            return new UserResponse(user.getId(), user.getName(), user.getEmail());
        }
    }

    public record TokenResponse(String accessToken, String refreshToken, String tokenType, long expiresIn,
            UserResponse user) {
    }
}
