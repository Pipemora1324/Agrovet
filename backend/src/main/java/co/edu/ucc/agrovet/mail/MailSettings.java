package co.edu.ucc.agrovet.mail;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Correo saliente. Si MAIL_USERNAME y MAIL_PASSWORD tienen valor, se envía por SMTP real con
 * STARTTLS obligatorio (por ejemplo Gmail con contraseña de aplicación). Si están vacías, los
 * correos van a Mailpit, el buzón de prueba del docker-compose.
 *
 * @param host        servidor SMTP real (MAIL_HOST, por defecto smtp.gmail.com)
 * @param port        puerto SMTP real (MAIL_PORT, por defecto 587)
 * @param username    usuario SMTP (MAIL_USERNAME)
 * @param password    contraseña SMTP (MAIL_PASSWORD); nunca se escribe en los logs
 * @param from        remitente (MAIL_FROM). Vacío: el usuario SMTP, o uno de prueba con Mailpit
 * @param mailpitHost servidor de Mailpit (MAILPIT_HOST)
 * @param mailpitPort puerto SMTP de Mailpit (MAILPIT_SMTP_PORT)
 * @param requireSmtp true en producción: sin SMTP real la aplicación no arranca
 * @param async       true: el correo sale en otro hilo, para que el tiempo de respuesta no revele si
 *                    la cuenta existe. Solo las pruebas lo ponen en false.
 */
@ConfigurationProperties("agrovet.mail")
public record MailSettings(String host, int port, String username, String password, String from,
        String mailpitHost, int mailpitPort, boolean requireSmtp, boolean async) {

    static final String TEST_SENDER = "AgroVet <no-responder@agrovet.local>";

    /** true si hay credenciales: se usa el SMTP real. */
    public boolean usesRealSmtp() {
        return !isBlank(username) && !isBlank(password);
    }

    /** Remitente efectivo de los correos. */
    public String effectiveFrom() {
        if (!isBlank(from)) {
            return from.trim();
        }
        return usesRealSmtp() ? username.trim() : TEST_SENDER;
    }

    static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
