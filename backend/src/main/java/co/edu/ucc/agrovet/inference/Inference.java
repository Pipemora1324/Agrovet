package co.edu.ucc.agrovet.inference;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Evaluación del semáforo hecha en el celular: el color final es el más grave entre el modelo LSTM y
 * el puntaje por síntomas, y {@code cause} dice cuál lo fijó.
 */
@Entity
@Table(name = "inferences")
public class Inference {

    @Id
    private UUID id;

    @Column(name = "cow_id", nullable = false)
    private UUID cowId;

    @Column(name = "window_end_date", nullable = false)
    private LocalDate windowEndDate;

    /** Probabilidad del modelo; null si no hubo días suficientes con datos numéricos. */
    @Column
    private Double probability;

    /** Puntaje por síntomas del día (reglas provisionales); null en evaluaciones anteriores. */
    @Column(name = "symptom_score")
    private Integer symptomScore;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private RiskCause cause;

    @Enumerated(EnumType.STRING)
    @Column(name = "risk_level", nullable = false, length = 10)
    private RiskLevel riskLevel;

    @Column(name = "model_version", nullable = false, length = 40)
    private String modelVersion;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(nullable = false)
    private boolean deleted;

    protected Inference() {
    }

    public Inference(UUID id, Instant createdAt) {
        this.id = id;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public void update(UUID cowId, LocalDate windowEndDate, Double probability, Integer symptomScore,
            RiskCause cause, RiskLevel riskLevel, String modelVersion, boolean deleted, Instant updatedAt) {
        this.cowId = cowId;
        this.windowEndDate = windowEndDate;
        this.probability = probability;
        this.symptomScore = symptomScore;
        this.cause = cause;
        this.riskLevel = riskLevel;
        this.modelVersion = modelVersion;
        this.deleted = deleted;
        this.updatedAt = updatedAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCowId() {
        return cowId;
    }

    public LocalDate getWindowEndDate() {
        return windowEndDate;
    }

    public Double getProbability() {
        return probability;
    }

    public Integer getSymptomScore() {
        return symptomScore;
    }

    public RiskCause getCause() {
        return cause;
    }

    public RiskLevel getRiskLevel() {
        return riskLevel;
    }

    public String getModelVersion() {
        return modelVersion;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
