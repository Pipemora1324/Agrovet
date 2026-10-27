package co.edu.ucc.agrovet.common;

/**
 * Recurso inexistente o de otro usuario. En ambos casos se responde 404 para no revelar
 * qué identificadores existen.
 */
public class NotFoundException extends RuntimeException {

    public NotFoundException(String message) {
        super(message);
    }
}
