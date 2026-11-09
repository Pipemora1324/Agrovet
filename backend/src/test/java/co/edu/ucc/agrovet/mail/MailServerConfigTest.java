package co.edu.ucc.agrovet.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.mail.javamail.JavaMailSenderImpl;

class MailServerConfigTest {

    private static MailSettings settings(String username, String password, String from, boolean requireSmtp) {
        return new MailSettings("smtp.gmail.com", 587, username, password, from, "mailpit", 1025, requireSmtp, true);
    }

    @Test
    void sinCredencialesUsaMailpitSinAutenticacion() {
        JavaMailSenderImpl sender = MailServerConfig.build(settings("", "", "", false));

        assertThat(sender.getHost()).isEqualTo("mailpit");
        assertThat(sender.getPort()).isEqualTo(1025);
        assertThat(sender.getUsername()).isNull();
        assertThat(sender.getJavaMailProperties()).containsEntry("mail.smtp.auth", "false");
        assertThat(settings("", "", "", false).effectiveFrom()).isEqualTo(MailSettings.TEST_SENDER);
    }

    @Test
    void conCredencialesUsaSmtpRealConStarttlsObligatorio() {
        MailSettings gmail = settings("finca@gmail.com", "abcd efgh ijkl mnop", "", false);
        JavaMailSenderImpl sender = MailServerConfig.build(gmail);

        assertThat(sender.getHost()).isEqualTo("smtp.gmail.com");
        assertThat(sender.getPort()).isEqualTo(587);
        assertThat(sender.getUsername()).isEqualTo("finca@gmail.com");
        assertThat(sender.getPassword()).isEqualTo("abcdefghijklmnop");
        assertThat(sender.getJavaMailProperties())
                .containsEntry("mail.smtp.auth", "true")
                .containsEntry("mail.smtp.starttls.enable", "true")
                .containsEntry("mail.smtp.starttls.required", "true");
        // Sin MAIL_FROM el remitente es la misma cuenta
        assertThat(gmail.effectiveFrom()).isEqualTo("finca@gmail.com");
        assertThat(settings("finca@gmail.com", "x", "AgroVet <finca@gmail.com>", false).effectiveFrom())
                .isEqualTo("AgroVet <finca@gmail.com>");
    }

    @Test
    void soloUsuarioSinContrasenaSigueEnMailpit() {
        assertThat(settings("finca@gmail.com", "", "", false).usesRealSmtp()).isFalse();
    }

    @Test
    void enProduccionSinSmtpRealNoArranca() {
        assertThatThrownBy(() -> MailServerConfig.build(settings("", "", "", true)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("MAIL_USERNAME");
    }
}
