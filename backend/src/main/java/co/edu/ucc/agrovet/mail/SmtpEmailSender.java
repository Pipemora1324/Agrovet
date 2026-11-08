package co.edu.ucc.agrovet.mail;

import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

/** Envía por el SMTP configurado con SMTP_HOST, SMTP_PORT, SMTP_USERNAME y SMTP_PASSWORD. */
@Component
class SmtpEmailSender implements EmailSender {

    private final JavaMailSender mailSender;
    private final MailSettings settings;

    SmtpEmailSender(JavaMailSender mailSender, MailSettings settings) {
        if (settings.from() == null || settings.from().isBlank()) {
            throw new IllegalStateException("Falta la variable de entorno MAIL_FROM.");
        }
        this.mailSender = mailSender;
        this.settings = settings;
    }

    @Override
    public void send(String to, String subject, String body) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(settings.from());
        message.setTo(to);
        message.setSubject(subject);
        message.setText(body);
        mailSender.send(message);
    }
}
