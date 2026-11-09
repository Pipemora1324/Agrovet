package co.edu.ucc.agrovet.auth;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import co.edu.ucc.agrovet.common.TooManyRequestsException;

@RestControllerAdvice
class AuthExceptionHandler {

    @ExceptionHandler(AuthenticationFailedException.class)
    ProblemDetail handleAuthenticationFailed(AuthenticationFailedException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, ex.getMessage());
        problem.setTitle("No autorizado");
        return problem;
    }

    @ExceptionHandler(EmailNotVerifiedException.class)
    ProblemDetail handleEmailNotVerified(EmailNotVerifiedException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.FORBIDDEN, ex.getMessage());
        problem.setTitle("Correo sin verificar");
        problem.setProperty("code", EmailNotVerifiedException.CODE);
        return problem;
    }

    @ExceptionHandler(InvalidCodeException.class)
    ProblemDetail handleInvalidCode(InvalidCodeException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.getMessage());
        problem.setTitle("Código inválido");
        return problem;
    }

    @ExceptionHandler(TooManyRequestsException.class)
    ResponseEntity<ProblemDetail> handleTooManyRequests(TooManyRequestsException ex) {
        long seconds = Math.max(1, ex.getRetryAfter().toSeconds());
        String wait = waitText(seconds);
        String detail = ex instanceof TooManyLoginAttemptsException
                ? "Demasiados intentos. Espere " + wait + " e intente de nuevo."
                : ex.getMessage() + " Intente de nuevo en " + wait + ".";
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.TOO_MANY_REQUESTS, detail);
        problem.setTitle("Demasiados intentos");
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .header(HttpHeaders.RETRY_AFTER, String.valueOf(seconds))
                .body(problem);
    }

    /** "1 segundo", "30 segundos", "1 minuto", "54 minutos" (los minutos se redondean hacia arriba). */
    static String waitText(long seconds) {
        if (seconds < 60) {
            return seconds == 1 ? "1 segundo" : seconds + " segundos";
        }
        long minutes = (seconds + 59) / 60;
        return minutes == 1 ? "1 minuto" : minutes + " minutos";
    }
}
