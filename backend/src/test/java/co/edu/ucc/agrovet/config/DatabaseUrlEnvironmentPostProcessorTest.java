package co.edu.ucc.agrovet.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.StandardEnvironment;

class DatabaseUrlEnvironmentPostProcessorTest {

    private final DatabaseUrlEnvironmentPostProcessor processor = new DatabaseUrlEnvironmentPostProcessor();

    private StandardEnvironment environment(Map<String, Object> variables) {
        StandardEnvironment env = new StandardEnvironment();
        env.getPropertySources().addLast(new MapPropertySource("variables", new HashMap<>(variables)));
        return env;
    }

    @Test
    void convierteLaDireccionDeRenderAJdbcConUsuarioYClave() {
        StandardEnvironment env = environment(Map.of(
                "DATABASE_URL", "postgresql://agrovet:Cl%40ve9@dpg-abc123-a:5432/agrovet"));
        processor.postProcessEnvironment(env, null);

        assertThat(env.getProperty("spring.datasource.url")).isEqualTo("jdbc:postgresql://dpg-abc123-a:5432/agrovet");
        assertThat(env.getProperty("spring.datasource.username")).isEqualTo("agrovet");
        assertThat(env.getProperty("spring.datasource.password")).isEqualTo("Cl@ve9");
    }

    @Test
    void usaElPuertoPorDefectoYConservaLosParametros() {
        Map<String, Object> props = DatabaseUrlEnvironmentPostProcessor.toDataSourceProperties(
                "postgres://u:p@db.ejemplo.co/agrovet?sslmode=require", false, false);
        assertThat(props).containsEntry("spring.datasource.url",
                "jdbc:postgresql://db.ejemplo.co:5432/agrovet?sslmode=require");
    }

    @Test
    void noTocaNadaSiDbUrlEstaDefinida() {
        StandardEnvironment env = environment(Map.of(
                "DB_URL", "jdbc:postgresql://localhost:5432/agrovet",
                "DATABASE_URL", "postgresql://otro:otra@lejos:5432/otra"));
        processor.postProcessEnvironment(env, null);

        assertThat(env.getPropertySources().contains(DatabaseUrlEnvironmentPostProcessor.SOURCE_NAME)).isFalse();
    }

    @Test
    void noHaceNadaSinDatabaseUrl() {
        StandardEnvironment env = environment(Map.of());
        processor.postProcessEnvironment(env, null);
        assertThat(env.getPropertySources().contains(DatabaseUrlEnvironmentPostProcessor.SOURCE_NAME)).isFalse();
    }

    @Test
    void respetaUsuarioYClaveDefinidosAparte() {
        Map<String, Object> props = DatabaseUrlEnvironmentPostProcessor.toDataSourceProperties(
                "postgresql://u:p@h:5432/agrovet", true, true);
        assertThat(props).containsOnlyKeys("spring.datasource.url");
    }

    @Test
    void rechazaDireccionesInvalidasSinRepetirLaClave() {
        assertThatThrownBy(() -> DatabaseUrlEnvironmentPostProcessor.toDataSourceProperties(
                "mysql://u:secreta@h/agrovet", false, false))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageNotContaining("secreta");
        assertThatThrownBy(() -> DatabaseUrlEnvironmentPostProcessor.toDataSourceProperties(
                "postgresql://u:secreta@h", false, false))
                .hasMessageContaining("nombre de la base")
                .hasMessageNotContaining("secreta");
        assertThatThrownBy(() -> DatabaseUrlEnvironmentPostProcessor.toDataSourceProperties(
                "postgresql://u:sec reta@h/x", false, false))
                .hasMessageNotContaining("sec reta");
    }
}
