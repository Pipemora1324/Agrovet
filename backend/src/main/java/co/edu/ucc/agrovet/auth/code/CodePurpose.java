package co.edu.ucc.agrovet.auth.code;

/** Para qué sirve un código: no se puede usar uno de verificación para cambiar la contraseña. */
public enum CodePurpose {
    VERIFY_EMAIL,
    RESET_PASSWORD
}
