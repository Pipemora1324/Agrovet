package co.edu.ucc.agrovet.record;

/**
 * Origen de la temperatura, la leche y el alimento de un registro: "measured" (medido) o
 * "estimated" (estimado por la app). null si no hay valor o si lo envió una versión anterior.
 */
public record ValueSources(String temperature, String milk, String feed) {

    public static final String PATTERN = "measured|estimated";

    public static final ValueSources NONE = new ValueSources(null, null, null);
}
