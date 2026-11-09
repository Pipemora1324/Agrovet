package co.edu.ucc.agrovet.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.Test;

class CorsPropertiesTest {

    @Test
    void limpiaEspaciosYVacios() {
        assertThat(new CorsProperties(List.of(" https://panel.agrovet.co ", "")).allowedOrigins())
                .containsExactly("https://panel.agrovet.co");
        assertThat(new CorsProperties(null).allowedOrigins()).isEmpty();
    }

    @Test
    void noAdmiteComodines() {
        assertThatThrownBy(() -> new CorsProperties(List.of("*"))).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new CorsProperties(List.of("https://*.agrovet.co")))
                .isInstanceOf(IllegalStateException.class);
    }
}
