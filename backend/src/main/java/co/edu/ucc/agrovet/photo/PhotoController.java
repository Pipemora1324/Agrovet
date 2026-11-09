package co.edu.ucc.agrovet.photo;

import java.io.IOException;
import java.time.Duration;
import java.util.UUID;

import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import co.edu.ucc.agrovet.common.BadRequestException;
import co.edu.ucc.agrovet.common.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/cows/{cowId}/photos/{photoId}/image")
@Tag(name = "Fotos")
@SecurityRequirement(name = "bearer")
public class PhotoController {

    private final PhotoService photoService;

    public PhotoController(PhotoService photoService) {
        this.photoService = photoService;
    }

    @PutMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Sube el archivo de una foto (JPEG o PNG); se guarda como JPEG sin metadatos",
            description = "Los datos de la foto deben haber llegado antes por /api/sync. Repetir la subida la reemplaza.")
    public void upload(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID cowId, @PathVariable UUID photoId,
            @RequestPart("file") MultipartFile file) {
        try {
            photoService.upload(CurrentUser.id(jwt), cowId, photoId, file.getBytes());
        } catch (IOException e) {
            throw new BadRequestException("No se pudo leer el archivo recibido.");
        }
    }

    @GetMapping(produces = MediaType.IMAGE_JPEG_VALUE)
    @Operation(summary = "Descarga la foto (solo su dueño)")
    public ResponseEntity<byte[]> download(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID cowId,
            @PathVariable UUID photoId) {
        byte[] jpeg = photoService.download(CurrentUser.id(jwt), cowId, photoId);
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                // Privada: ningún intermediario la guarda
                .cacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePrivate())
                .header("X-Content-Type-Options", "nosniff")
                .body(jpeg);
    }
}
