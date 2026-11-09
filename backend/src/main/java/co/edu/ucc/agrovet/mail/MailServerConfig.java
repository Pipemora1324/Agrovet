package co.edu.ucc.agrovet.mail;

import java.util.Properties;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;

/** Elige entre el SMTP real (con STARTTLS) y Mailpit según las variables MAIL_*. */
@Configuration
class MailServerConfig {

    private static final Logger log = LoggerFactory.getLogger(MailServerConfig.class);
    private static final String TIMEOUT_MS = "10000";

    @Bean
    JavaMailSender javaMailSender(MailSettings settings) {
        return build(settings);
    }

    static JavaMailSenderImpl build(MailSettings settings) {
        JavaMailSenderImpl sender = new JavaMailSenderImpl();
        sender.setDefaultEncoding("UTF-8");
        Properties props = sender.getJavaMailProperties();
        props.put("mail.smtp.connectiontimeout", TIMEOUT_MS);
        props.put("mail.smtp.timeout", TIMEOUT_MS);
        props.put("mail.smtp.writetimeout", TIMEOUT_MS);
        if (settings.usesRealSmtp()) {
            if (MailSettings.isBlank(settings.host())) {
                throw new IllegalStateException("Falta la variable de entorno MAIL_HOST.");
            }
            sender.setHost(settings.host().trim());
            sender.setPort(settings.port());
            sender.setUsername(settings.username().trim());
            // La contraseña de aplicación de Gmail se muestra con espacios; se aceptan pegada con ellos
            sender.setPassword(settings.password().replace(" ", ""));
            props.put("mail.smtp.auth", "true");
            props.put("mail.smtp.starttls.enable", "true");
            // Sin TLS no se envía: la contraseña nunca viaja en claro
            props.put("mail.smtp.starttls.required", "true");
            log.info("Correo: SMTP {}:{} con STARTTLS", settings.host().trim(), settings.port());
        } else {
            if (settings.requireSmtp()) {
                throw new IllegalStateException(
                        "En producción se requiere un SMTP real: defina MAIL_USERNAME y MAIL_PASSWORD.");
            }
            sender.setHost(settings.mailpitHost());
            sender.setPort(settings.mailpitPort());
            props.put("mail.smtp.auth", "false");
            props.put("mail.smtp.starttls.enable", "false");
            log.info("Correo: Mailpit en {}:{} (MAIL_USERNAME vacío)", settings.mailpitHost(), settings.mailpitPort());
        }
        return sender;
    }
}
