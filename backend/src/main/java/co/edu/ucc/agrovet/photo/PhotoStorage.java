package co.edu.ucc.agrovet.photo;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Component;

/**
 * Archivos de las fotos en disco. El nombre es solo el UUID de la foto (nunca un dato del cliente),
 * así no hay forma de escribir fuera de la carpeta.
 */
@Component
public class PhotoStorage {

    private final Path root;

    public PhotoStorage(PhotoProperties properties) {
        this.root = properties.storageDir().toAbsolutePath().normalize();
        try {
            Files.createDirectories(root);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo crear la carpeta de fotos " + root, e);
        }
    }

    private Path pathFor(UUID photoId) {
        return root.resolve(photoId + ".jpg");
    }

    /** Escribe primero en un temporal y luego lo mueve: nunca queda un archivo a medias. */
    public void save(UUID photoId, byte[] jpeg) {
        try {
            Path temp = Files.createTempFile(root, "subida-", ".tmp");
            Files.write(temp, jpeg);
            Files.move(temp, pathFor(photoId), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo guardar la foto " + photoId, e);
        }
    }

    public Optional<byte[]> read(UUID photoId) {
        Path path = pathFor(photoId);
        try {
            return Files.exists(path) ? Optional.of(Files.readAllBytes(path)) : Optional.empty();
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo leer la foto " + photoId, e);
        }
    }

    public void delete(UUID photoId) {
        try {
            Files.deleteIfExists(pathFor(photoId));
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo borrar la foto " + photoId, e);
        }
    }
}
