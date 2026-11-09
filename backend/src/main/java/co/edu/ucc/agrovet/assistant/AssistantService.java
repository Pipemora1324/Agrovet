package co.edu.ucc.agrovet.assistant;

import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;

import co.edu.ucc.agrovet.assistant.AssistantDtos.ChatRequest;
import co.edu.ucc.agrovet.assistant.AssistantDtos.ChatResponse;
import co.edu.ucc.agrovet.common.BadRequestException;
import co.edu.ucc.agrovet.photo.PhotoProcessor;

/**
 * Arma la conversación (contexto de la vaca, mensajes anteriores y la pregunta), limpia la foto y
 * consulta al proveedor. La foto pasa por el mismo control que las fotos de las vacas: tipo real,
 * tamaño y sin metadatos (la ubicación no sale del servidor).
 */
@Service
public class AssistantService {

    static final int MAX_ANSWER = 2000;

    private final LlmClient llm;
    private final AssistantRateLimiter limiter;
    private final PhotoProcessor photos;

    public AssistantService(LlmClient llm, AssistantRateLimiter limiter, PhotoProcessor photos) {
        this.llm = llm;
        this.limiter = limiter;
        this.photos = photos;
    }

    public ChatResponse chat(UUID userId, ChatRequest request) {
        byte[] jpeg = decodePhoto(request.photoBase64());
        limiter.acquire(userId);

        List<LlmClient.Turn> turns = new ArrayList<>();
        turns.add(new LlmClient.Turn(true, AssistantPrompt.context(request.context())));
        turns.add(new LlmClient.Turn(false, "Entendido. ¿En qué le puedo ayudar?"));
        request.history().forEach(turn -> turns.add(new LlmClient.Turn(turn.fromUser(), turn.text().trim())));
        turns.add(new LlmClient.Turn(true, request.question().trim()));

        String answer = llm.generate(AssistantPrompt.SYSTEM, turns, jpeg);
        return new ChatResponse(answer.length() > MAX_ANSWER ? answer.substring(0, MAX_ANSWER) + "…" : answer);
    }

    private byte[] decodePhoto(String base64) {
        if (base64 == null || base64.isBlank()) {
            return null;
        }
        byte[] raw;
        try {
            raw = Base64.getDecoder().decode(base64.trim());
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("La foto no llegó completa. Intente de nuevo.");
        }
        return photos.clean(raw);
    }
}
