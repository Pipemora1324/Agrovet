package co.edu.ucc.agrovet.assistant;

/** El proveedor no está configurado, no respondió a tiempo o devolvió un error. Responde 503. */
public class AssistantUnavailableException extends RuntimeException {

    public AssistantUnavailableException(String reason) {
        super(reason);
    }

    public AssistantUnavailableException(String reason, Throwable cause) {
        super(reason, cause);
    }
}
