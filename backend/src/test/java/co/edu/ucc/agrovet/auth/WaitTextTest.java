package co.edu.ucc.agrovet.auth;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** El tiempo de espera de un 429 se lee bien en español (prueba en emulador, 2026-11-09). */
class WaitTextTest {

    @Test
    void usesSingularPluralAndRoundsMinutesUp() {
        assertThat(AuthExceptionHandler.waitText(1)).isEqualTo("1 segundo");
        assertThat(AuthExceptionHandler.waitText(45)).isEqualTo("45 segundos");
        assertThat(AuthExceptionHandler.waitText(60)).isEqualTo("1 minuto");
        assertThat(AuthExceptionHandler.waitText(61)).isEqualTo("2 minutos");
        assertThat(AuthExceptionHandler.waitText(3239)).isEqualTo("54 minutos");
    }
}
