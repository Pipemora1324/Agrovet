package co.edu.ucc.agrovet.assistant;

/** El proveedor no está configurado, no respondió a tiempo o devolvió un error. Responde 503. */
public class AssistantUnavailableException extends RuntimeException {

    private static final String DEFAULT_USER_MESSAGE =
            "El asistente no está disponible en este momento. Intente más tarde.";

    private final String userMessage;

    public AssistantUnavailableException(String reason) {
        this(reason, DEFAULT_USER_MESSAGE, null);
    }

    public AssistantUnavailableException(String reason, Throwable cause) {
        this(reason, DEFAULT_USER_MESSAGE, cause);
    }

    public AssistantUnavailableException(String reason, String userMessage, Throwable cause) {
        super(reason, cause);
        this.userMessage = userMessage;
    }

    public String userMessage() {
        return userMessage;
    }
}
