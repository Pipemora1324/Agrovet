package co.edu.ucc.agrovet.record;

/** Checklist de síntomas visibles del registro diario. */
public record Symptoms(boolean udderSwelling, boolean abnormalMilk, boolean udderPain, boolean lethargy) {

    public static final Symptoms NONE = new Symptoms(false, false, false, false);
}
