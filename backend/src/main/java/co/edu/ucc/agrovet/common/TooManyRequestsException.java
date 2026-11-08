package co.edu.ucc.agrovet.common;

import java.time.Duration;

/** Se superó un límite de uso; la respuesta es 429 con la cabecera Retry-After. */
public class TooManyRequestsException extends RuntimeException {

    private final Duration retryAfter;

    public TooManyRequestsException(String message, Duration retryAfter) {
        super(message);
        this.retryAfter = retryAfter;
    }

    public Duration getRetryAfter() {
        return retryAfter;
    }
}
