package co.edu.ucc.agrovet.user;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class User {

    @Id
    private UUID id;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, length = 254)
    private String email;

    @Column(name = "password_hash", nullable = false, length = 100)
    private String passwordHash;

    @Column(name = "email_verified", nullable = false)
    private boolean emailVerified;

    @Column(name = "farm_name", length = 100)
    private String farmName;

    @Column(length = 80)
    private String municipality;

    @Column(length = 20)
    private String phone;

    @Column(name = "privacy_policy_version", length = 20)
    private String privacyPolicyVersion;

    @Column(name = "privacy_accepted_at")
    private Instant privacyAcceptedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected User() {
    }

    /** Cuenta nueva, todavía sin verificar el correo. */
    public User(String name, String email, String passwordHash, Instant now) {
        this.id = UUID.randomUUID();
        this.name = name;
        this.email = email;
        this.passwordHash = passwordHash;
        this.createdAt = now;
        this.updatedAt = now;
    }

    /**
     * Registro repetido sobre una cuenta sin verificar: nadie ha demostrado ser el dueño del correo,
     * así que el último registro reemplaza nombre y contraseña.
     */
    public void replaceUnverifiedRegistration(String name, String passwordHash, Instant now) {
        if (emailVerified) {
            throw new IllegalStateException("La cuenta ya está verificada.");
        }
        this.name = name;
        this.passwordHash = passwordHash;
        this.updatedAt = now;
    }

    public void markEmailVerified(Instant now) {
        this.emailVerified = true;
        this.updatedAt = now;
    }

    public void changePassword(String passwordHash, Instant now) {
        this.passwordHash = passwordHash;
        this.updatedAt = now;
    }

    public void updateProfile(String name, String farmName, String municipality, String phone, Instant now) {
        this.name = name;
        this.farmName = farmName;
        this.municipality = municipality;
        this.phone = phone;
        this.updatedAt = now;
    }

    /** Registra la aceptación del aviso de privacidad (versión y momento). */
    public void acceptPrivacyPolicy(String version, Instant now) {
        this.privacyPolicyVersion = version;
        this.privacyAcceptedAt = now;
        this.updatedAt = now;
    }

    public String getFarmName() {
        return farmName;
    }

    public String getMunicipality() {
        return municipality;
    }

    public String getPhone() {
        return phone;
    }

    public String getPrivacyPolicyVersion() {
        return privacyPolicyVersion;
    }

    public Instant getPrivacyAcceptedAt() {
        return privacyAcceptedAt;
    }

    public UUID getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public boolean isEmailVerified() {
        return emailVerified;
    }
}
