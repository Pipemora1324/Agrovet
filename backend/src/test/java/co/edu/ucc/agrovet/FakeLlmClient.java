package co.edu.ucc.agrovet;

import java.util.List;

import co.edu.ucc.agrovet.assistant.AssistantUnavailableException;
import co.edu.ucc.agrovet.assistant.LlmClient;

/** Proveedor simulado: responde un texto fijo y guarda lo último que recibió. */
public class FakeLlmClient implements LlmClient {

    public volatile String lastSystemPrompt;
    public volatile List<Turn> lastTurns;
    public volatile byte[] lastPhoto;
    public volatile boolean failing;

    @Override
    public String generate(String systemPrompt, List<Turn> turns, byte[] jpeg) {
        if (failing) {
            throw new AssistantUnavailableException("simulado");
        }
        lastSystemPrompt = systemPrompt;
        lastTurns = turns;
        lastPhoto = jpeg;
        return "Revise la ubre en el próximo ordeño y, si ve sangre o la vaca tiene fiebre, llame al veterinario.";
    }
}
