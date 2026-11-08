package co.edu.ucc.agrovet.inference;

/** Qué indicador fijó el color final del semáforo. */
public enum RiskCause {
    /** El modelo LSTM. */
    MODEL,
    /** El puntaje por síntomas. */
    SYMPTOMS,
    /** Los dos dieron el mismo color. */
    BOTH
}
