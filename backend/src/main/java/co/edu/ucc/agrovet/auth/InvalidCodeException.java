package co.edu.ucc.agrovet.auth;

/** Código incorrecto, vencido o agotado. El mensaje es el mismo en todos los casos (y si el correo no existe). */
public class InvalidCodeException extends RuntimeException {

    public InvalidCodeException() {
        super("El código no es válido o ya venció. Revise el correo o pida uno nuevo.");
    }
}
