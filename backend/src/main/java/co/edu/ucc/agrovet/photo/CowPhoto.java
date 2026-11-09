package co.edu.ucc.agrovet.photo;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "cow_photos")
public class CowPhoto {

    @Id
    private UUID id;

    @Column(name = "cow_id", nullable = false)
    private UUID cowId;

    @Column(name = "taken_on", nullable = false)
    private LocalDate takenOn;

    @Column(nullable = false)
    private boolean stored;

    @Column(name = "size_bytes")
    private Integer sizeBytes;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(nullable = false)
    private boolean deleted;

    @Enumerated(EnumType.STRING)
    @Column(name = "vet_confirmed", length = 10)
    private VetConfirmation vetConfirmed;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Diagnosis diagnosis;

    @Column(name = "diagnosis_notes", length = 300)
    private String diagnosisNotes;

    @Column(name = "research_consent", nullable = false)
    private boolean researchConsent;

    @Column(name = "research_consent_at")
    private Instant researchConsentAt;

    protected CowPhoto() {
    }

    public CowPhoto(UUID id, Instant createdAt) {
        this.id = id;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public void update(UUID cowId, LocalDate takenOn, boolean deleted, Instant updatedAt) {
        this.cowId = cowId;
        this.takenOn = takenOn;
        this.deleted = deleted;
        this.updatedAt = updatedAt;
    }

    /**
     * Datos de investigación. La fecha del consentimiento se guarda al darlo y se borra al retirarlo.
     */
    public void updateResearch(VetConfirmation vetConfirmed, Diagnosis diagnosis, String diagnosisNotes,
            boolean researchConsent, Instant now) {
        this.vetConfirmed = vetConfirmed;
        this.diagnosis = diagnosis;
        this.diagnosisNotes = diagnosisNotes;
        if (researchConsent && !this.researchConsent) {
            this.researchConsentAt = now;
        } else if (!researchConsent) {
            this.researchConsentAt = null;
        }
        this.researchConsent = researchConsent;
    }

    public void markStored(int sizeBytes) {
        this.stored = true;
        this.sizeBytes = sizeBytes;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCowId() {
        return cowId;
    }

    public LocalDate getTakenOn() {
        return takenOn;
    }

    public boolean isStored() {
        return stored;
    }

    public boolean isDeleted() {
        return deleted;
    }

    public VetConfirmation getVetConfirmed() {
        return vetConfirmed;
    }

    public Diagnosis getDiagnosis() {
        return diagnosis;
    }

    public boolean isResearchConsent() {
        return researchConsent;
    }

    public Instant getResearchConsentAt() {
        return researchConsentAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
