package co.edu.ucc.agrovet.auth;

import java.time.Duration;

import co.edu.ucc.agrovet.common.TooManyRequestsException;

public class TooManyLoginAttemptsException extends TooManyRequestsException {

    public TooManyLoginAttemptsException(Duration retryAfter) {
        super("Demasiados intentos de inicio de sesión.", retryAfter);
    }
}
