package co.edu.ucc.agrovet.auth;

/**
 * Contraseña correcta pero correo sin verificar. Solo se lanza después de comprobar la contraseña,
 * así que no revela a terceros si el correo está registrado.
 */
public class EmailNotVerifiedException extends RuntimeException {

    /** Valor del campo "code" de la respuesta, que la app usa para abrir la pantalla del código. */
    public static final String CODE = "EMAIL_NOT_VERIFIED";

    public EmailNotVerifiedException() {
        super("Debe verificar su correo antes de ingresar. Escriba el código que le enviamos.");
    }
}
