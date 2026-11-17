package co.edu.ucc.agrovet.config;

import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import org.springframework.util.StringUtils;

/**
 * Acepta la conexión a la base en el formato de Render
 * ({@code DATABASE_URL=postgresql://usuario:clave@host:puerto/base}).
 *
 * <p>Spring necesita la dirección en formato JDBC ({@code DB_URL}) y el usuario y la clave aparte. Si
 * {@code DB_URL} está definida no se hace nada (docker-compose y la VPS siguen igual). Si no, y existe
 * {@code DATABASE_URL}, se arma la dirección JDBC y, si faltan, el usuario y la clave salen de ella.
 * Así el Blueprint de Render enlaza la base sin copiar nada a mano. Ningún mensaje repite la dirección,
 * porque lleva la clave.
 */
public class DatabaseUrlEnvironmentPostProcessor implements EnvironmentPostProcessor {

    static final String SOURCE_NAME = "agrovetDatabaseUrl";
    private static final int DEFAULT_PORT = 5432;

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        if (StringUtils.hasText(environment.getProperty("DB_URL"))) {
            return;
        }
        String databaseUrl = environment.getProperty("DATABASE_URL");
        if (!StringUtils.hasText(databaseUrl)) {
            return;
        }
        Map<String, Object> properties = toDataSourceProperties(databaseUrl.trim(),
                StringUtils.hasText(environment.getProperty("DB_USERNAME")),
                StringUtils.hasText(environment.getProperty("DB_PASSWORD")));
        environment.getPropertySources().addFirst(new MapPropertySource(SOURCE_NAME, properties));
    }

    static Map<String, Object> toDataSourceProperties(String databaseUrl, boolean hasUsername, boolean hasPassword) {
        URI uri;
        try {
            uri = new URI(databaseUrl);
        } catch (URISyntaxException e) {
            throw invalid("no es una dirección válida");
        }
        String scheme = uri.getScheme();
        if (!"postgresql".equals(scheme) && !"postgres".equals(scheme)) {
            throw invalid("debe empezar con postgresql://");
        }
        String host = uri.getHost();
        String path = uri.getRawPath();
        if (!StringUtils.hasText(host) || path == null || path.length() < 2) {
            throw invalid("le falta el servidor o el nombre de la base");
        }
        int port = uri.getPort() > 0 ? uri.getPort() : DEFAULT_PORT;
        String jdbcUrl = "jdbc:postgresql://" + host + ":" + port + path
                + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : "");

        Map<String, Object> properties = new HashMap<>();
        properties.put("spring.datasource.url", jdbcUrl);
        String userInfo = uri.getRawUserInfo();
        if (userInfo != null) {
            int colon = userInfo.indexOf(':');
            String user = colon >= 0 ? userInfo.substring(0, colon) : userInfo;
            if (!hasUsername && !user.isEmpty()) {
                properties.put("spring.datasource.username", decode(user));
            }
            if (!hasPassword && colon >= 0) {
                properties.put("spring.datasource.password", decode(userInfo.substring(colon + 1)));
            }
        }
        return properties;
    }

    private static String decode(String value) {
        return URLDecoder.decode(value, StandardCharsets.UTF_8);
    }

    private static IllegalStateException invalid(String reason) {
        return new IllegalStateException("La variable DATABASE_URL " + reason + ".");
    }
}
