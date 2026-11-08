package co.edu.ucc.agrovet;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import co.edu.ucc.agrovet.mail.EmailSender;

/** Remitente de prueba: guarda los correos en memoria en lugar de enviarlos. */
public class RecordingEmailSender implements EmailSender {

    public record SentEmail(String to, String subject, String body) {
    }

    private static final Pattern CODE = Pattern.compile("\\b(\\d{6})\\b");

    private final List<SentEmail> sent = new CopyOnWriteArrayList<>();

    @Override
    public void send(String to, String subject, String body) {
        sent.add(new SentEmail(to, subject, body));
    }

    public List<SentEmail> sentTo(String email) {
        return sent.stream().filter(m -> m.to().equalsIgnoreCase(email)).toList();
    }

    /** Código de 6 números del último correo enviado a esa dirección. */
    public String lastCode(String email) {
        List<SentEmail> messages = sentTo(email);
        if (messages.isEmpty()) {
            throw new AssertionError("No se envió ningún correo a " + email);
        }
        Matcher matcher = CODE.matcher(messages.getLast().body());
        if (!matcher.find()) {
            throw new AssertionError("El último correo a " + email + " no trae código");
        }
        return matcher.group(1);
    }
}
