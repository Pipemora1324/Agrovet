package co.edu.ucc.agrovet.auth.code;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "email_codes")
public class EmailCode {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CodePurpose purpose;

    @Column(name = "code_hash", nullable = false, length = 64)
    private String codeHash;

    @Column(nullable = false)
    private int attempts;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "consumed_at")
    private Instant consumedAt;

    protected EmailCode() {
    }

    public EmailCode(UUID userId, CodePurpose purpose, String codeHash, Instant now, Instant expiresAt) {
        this.id = UUID.randomUUID();
        this.userId = userId;
        this.purpose = purpose;
        this.codeHash = codeHash;
        this.createdAt = now;
        this.expiresAt = expiresAt;
    }

    /** Vigente: sin usar, sin anular y sin vencer. */
    public boolean isActive(Instant now) {
        return consumedAt == null && now.isBefore(expiresAt);
    }

    /** Cuenta un intento fallido; al llegar al máximo el código deja de servir. */
    void registerFailedAttempt(int maxAttempts, Instant now) {
        attempts++;
        if (attempts >= maxAttempts) {
            consumedAt = now;
        }
    }

    void consume(Instant now) {
        consumedAt = now;
    }

    public UUID getUserId() {
        return userId;
    }

    public CodePurpose getPurpose() {
        return purpose;
    }

    public String getCodeHash() {
        return codeHash;
    }

    public int getAttempts() {
        return attempts;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
