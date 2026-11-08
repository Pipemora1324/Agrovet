package co.edu.ucc.agrovet.mail;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param from  remitente de los correos (variable MAIL_FROM)
 * @param async true: el correo sale en otro hilo, para que el tiempo de respuesta no revele si la
 *              cuenta existe. Solo las pruebas lo ponen en false.
 */
@ConfigurationProperties("agrovet.mail")
public record MailSettings(String from, boolean async) {
}
