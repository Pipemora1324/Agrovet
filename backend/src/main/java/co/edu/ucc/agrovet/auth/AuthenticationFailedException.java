package co.edu.ucc.agrovet.auth;

/** Credenciales o refresh token inválidos. El mensaje se muestra tal cual al usuario. */
public class AuthenticationFailedException extends RuntimeException {

    public AuthenticationFailedException(String message) {
        super(message);
    }
}
