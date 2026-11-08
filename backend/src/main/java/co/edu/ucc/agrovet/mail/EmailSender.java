package co.edu.ucc.agrovet.mail;

/** Envío de un correo de texto plano. Separado para poder reemplazarlo en las pruebas. */
public interface EmailSender {

    void send(String to, String subject, String body);
}
