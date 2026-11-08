package co.edu.ucc.agrovet.auth.code;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EmailCodeRepository extends JpaRepository<EmailCode, UUID> {

    /** El código más reciente sin usar. Bloquea la fila para que dos intentos simultáneos cuenten ambos. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<EmailCode> findFirstByUserIdAndPurposeAndConsumedAtIsNullOrderByCreatedAtDesc(UUID userId,
            CodePurpose purpose);

    long countByUserIdAndPurposeAndCreatedAtAfter(UUID userId, CodePurpose purpose, Instant since);

    @Modifying
    @Query("UPDATE EmailCode c SET c.consumedAt = :now "
            + "WHERE c.userId = :userId AND c.purpose = :purpose AND c.consumedAt IS NULL")
    int consumeAll(@Param("userId") UUID userId, @Param("purpose") CodePurpose purpose, @Param("now") Instant now);

    @Modifying
    @Query("DELETE FROM EmailCode c WHERE c.userId = :userId")
    int deleteByUserId(@Param("userId") UUID userId);
}
