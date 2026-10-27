package co.edu.ucc.agrovet.cow;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CowRepository extends JpaRepository<Cow, UUID> {

    List<Cow> findAllByOwnerIdAndDeletedFalseOrderByTagAsc(UUID ownerId);

    Optional<Cow> findByIdAndOwnerIdAndDeletedFalse(UUID id, UUID ownerId);

    boolean existsByOwnerIdAndTagAndDeletedFalseAndIdNot(UUID ownerId, String tag, UUID id);
}
