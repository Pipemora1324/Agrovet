package co.edu.ucc.agrovet.photo;

import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import co.edu.ucc.agrovet.common.NotFoundException;
import co.edu.ucc.agrovet.cow.CowRepository;

/**
 * Archivos de las fotos. Los datos de la foto llegan antes por /api/sync; aquí solo se recibe y se
 * entrega la imagen. Una foto ajena, borrada o de otra vaca responde 404, igual que una inexistente.
 */
@Service
public class PhotoService {

    static final String NOT_FOUND = "La foto no existe.";

    private final CowPhotoRepository photos;
    private final CowRepository cows;
    private final PhotoProcessor processor;
    private final PhotoStorage storage;

    public PhotoService(CowPhotoRepository photos, CowRepository cows, PhotoProcessor processor, PhotoStorage storage) {
        this.photos = photos;
        this.cows = cows;
        this.processor = processor;
        this.storage = storage;
    }

    @Transactional
    public void upload(UUID ownerId, UUID cowId, UUID photoId, byte[] content) {
        CowPhoto photo = owned(ownerId, cowId, photoId);
        byte[] clean = processor.clean(content);
        storage.save(photo.getId(), clean);
        photo.markStored(clean.length);
    }

    @Transactional(readOnly = true)
    public byte[] download(UUID ownerId, UUID cowId, UUID photoId) {
        CowPhoto photo = owned(ownerId, cowId, photoId);
        return storage.read(photo.getId()).orElseThrow(() -> new NotFoundException("La foto todavía no se ha subido."));
    }

    private CowPhoto owned(UUID ownerId, UUID cowId, UUID photoId) {
        cows.findByIdAndOwnerIdAndDeletedFalse(cowId, ownerId).orElseThrow(() -> new NotFoundException(NOT_FOUND));
        return photos.findById(photoId)
                .filter(p -> !p.isDeleted() && p.getCowId().equals(cowId))
                .orElseThrow(() -> new NotFoundException(NOT_FOUND));
    }
}
