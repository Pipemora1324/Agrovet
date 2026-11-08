package co.edu.ucc.agrovet.mail;

import java.time.Duration;
import java.util.concurrent.Executor;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.task.SimpleAsyncTaskExecutor;
import org.springframework.core.task.SyncTaskExecutor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Correos de la cuenta. Se envían después de confirmar la transacción (si algo falla antes, no sale
 * un código que no quedó guardado) y, fuera de las pruebas, en otro hilo: así el tiempo de respuesta
 * es el mismo exista o no la cuenta. El código nunca se escribe en los logs.
 */
@Component
public class AccountMailer {

    private static final Logger log = LoggerFactory.getLogger(AccountMailer.class);

    private final EmailSender sender;
    private final Executor executor;

    public AccountMailer(EmailSender sender, MailSettings settings) {
        this.sender = sender;
        if (settings.async()) {
            SimpleAsyncTaskExecutor async = new SimpleAsyncTaskExecutor("correo-");
            async.setVirtualThreads(true);
            this.executor = async;
        } else {
            this.executor = new SyncTaskExecutor();
        }
    }

    public void sendVerificationCode(String to, String name, String code, Duration ttl) {
        send(to, "AgroVet: su código de verificación",
                "Hola, " + name + ".\n\n"
                        + "Su código para verificar el correo en AgroVet es:\n\n"
                        + "    " + code + "\n\n"
                        + "Vence en " + ttl.toMinutes() + " minutos. Si usted no creó una cuenta, ignore este mensaje.\n");
    }

    public void sendPasswordResetCode(String to, String name, String code, Duration ttl) {
        send(to, "AgroVet: código para cambiar la contraseña",
                "Hola, " + name + ".\n\n"
                        + "Su código para crear una contraseña nueva en AgroVet es:\n\n"
                        + "    " + code + "\n\n"
                        + "Vence en " + ttl.toMinutes() + " minutos. Si usted no lo pidió, ignore este mensaje: "
                        + "su contraseña sigue igual.\n");
    }

    public void sendAccountAlreadyExists(String to, String name) {
        send(to, "AgroVet: intento de registro con su correo",
                "Hola, " + name + ".\n\n"
                        + "Alguien intentó crear una cuenta de AgroVet con este correo, que ya está registrado.\n"
                        + "Si fue usted y no recuerda la contraseña, use \"Olvidé mi contraseña\" en la app.\n"
                        + "Si no fue usted, no tiene que hacer nada.\n");
    }

    private void send(String to, String subject, String body) {
        Runnable task = () -> {
            try {
                sender.send(to, subject, body);
            } catch (RuntimeException e) {
                log.warn("No se pudo enviar el correo \"{}\" a {}: {}", subject, mask(to), e.getMessage());
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    executor.execute(task);
                }
            });
        } else {
            executor.execute(task);
        }
    }

    /** a***@correo.co: suficiente para depurar sin dejar el correo completo en los logs. */
    static String mask(String email) {
        int at = email.indexOf('@');
        return at <= 1 ? "***" + email.substring(Math.max(at, 0)) : email.charAt(0) + "***" + email.substring(at);
    }
}
