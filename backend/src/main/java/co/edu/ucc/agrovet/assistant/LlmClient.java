package co.edu.ucc.agrovet.assistant;

import java.util.List;

/** Proveedor del modelo de lenguaje. Separado para poder cambiarlo y simularlo en las pruebas. */
public interface LlmClient {

    /** Un turno de la conversación: quién habla y qué dijo. */
    record Turn(boolean fromUser, String text) {
    }

    /**
     * @param systemPrompt instrucciones fijas del asistente
     * @param turns        conversación, terminando en la pregunta actual del usuario
     * @param jpeg         foto ya limpia (sin metadatos) para la pregunta actual, o null
     * @return texto de la respuesta
     * @throws AssistantUnavailableException si el proveedor no está configurado o falla
     */
    String generate(String systemPrompt, List<Turn> turns, byte[] jpeg);
}
