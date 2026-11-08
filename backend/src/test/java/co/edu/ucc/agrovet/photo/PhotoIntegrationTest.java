package co.edu.ucc.agrovet.photo;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import com.fasterxml.jackson.databind.ObjectMapper;

import co.edu.ucc.agrovet.IntegrationTest;
import co.edu.ucc.agrovet.RecordingEmailSender;
import co.edu.ucc.agrovet.TestUsers;
import co.edu.ucc.agrovet.TestUsers.TestUser;

class PhotoIntegrationTest extends IntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    RecordingEmailSender mail;
    @Autowired
    PhotoProperties properties;

    private TestUser ana;
    private TestUser beto;
    private UUID cowId;
    private UUID photoId;

    @BeforeEach
    void setUp() throws Exception {
        ana = TestUsers.register(mvc, json, mail);
        beto = TestUsers.register(mvc, json, mail);
        cowId = UUID.randomUUID();
        photoId = UUID.randomUUID();
        syncPhoto(ana, photoId, false);
    }

    private void syncPhoto(TestUser user, UUID id, boolean deleted) throws Exception {
        String now = Instant.now().toString();
        mvc.perform(post("/api/sync").header("Authorization", user.bearer()).contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"cows":[{"id":"%s","tag":"F-1","productionStatus":"LACTATING","updatedAt":"%s"}],
                                 "photos":[{"id":"%s","cowId":"%s","takenOn":"%s","updatedAt":"%s","deleted":%s}]}
                                """.formatted(cowId, now, id, cowId, LocalDate.now(), now, deleted)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rejected").isEmpty())
                .andExpect(jsonPath("$.confirmed.photos[0]").value(id.toString()));
    }

    private String imageUrl(UUID photo) {
        return "/api/cows/" + cowId + "/photos/" + photo + "/image";
    }

    private ResultActions upload(TestUser user, UUID photo, byte[] content, String contentType) throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", "ubre.jpg", contentType, content);
        return mvc.perform(multipart(imageUrl(photo)).file(file).with(request -> {
            request.setMethod("PUT");
            return request;
        }).header("Authorization", user.bearer()));
    }

    static byte[] image(String format, int width, int height) throws Exception {
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                image.setRGB(x, y, (x * 7 + y * 3) & 0xFFFFFF);
            }
        }
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(image, format, out);
        return out.toByteArray();
    }

    /** Inserta un segmento EXIF con coordenadas GPS justo después del inicio del JPEG. */
    static byte[] withGpsExif(byte[] jpeg) {
        byte[] payload = "Exif\0\0GPSLatitude=1.2136;GPSLongitude=-77.2811".getBytes(StandardCharsets.ISO_8859_1);
        int length = payload.length + 2;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(jpeg, 0, 2);
        out.write(0xFF);
        out.write(0xE1);
        out.write(length >> 8);
        out.write(length & 0xFF);
        out.write(payload, 0, payload.length);
        out.write(jpeg, 2, jpeg.length - 2);
        return out.toByteArray();
    }

    @Test
    void uploadedPhotoLosesItsLocationAndOnlyTheOwnerCanSeeIt() throws Exception {
        byte[] original = withGpsExif(image("jpg", 64, 48));
        assertThat(new String(original, StandardCharsets.ISO_8859_1)).contains("GPSLatitude");

        upload(ana, photoId, original, MediaType.IMAGE_JPEG_VALUE).andExpect(status().isNoContent());

        byte[] stored = mvc.perform(get(imageUrl(photoId)).header("Authorization", ana.bearer()))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", MediaType.IMAGE_JPEG_VALUE))
                .andExpect(header().string("Cache-Control", "max-age=3600, private"))
                .andReturn().getResponse().getContentAsByteArray();
        String text = new String(stored, StandardCharsets.ISO_8859_1);
        assertThat(text).doesNotContain("GPS").doesNotContain("Exif");
        BufferedImage decoded = ImageIO.read(new ByteArrayInputStream(stored));
        assertThat(decoded.getWidth()).isEqualTo(64);
        assertThat(decoded.getHeight()).isEqualTo(48);

        // Otro usuario no la ve ni la puede reemplazar: igual que si no existiera
        mvc.perform(get(imageUrl(photoId)).header("Authorization", beto.bearer())).andExpect(status().isNotFound());
        upload(beto, photoId, image("jpg", 8, 8), MediaType.IMAGE_JPEG_VALUE).andExpect(status().isNotFound());
        mvc.perform(get(imageUrl(photoId))).andExpect(status().isUnauthorized());
    }

    @Test
    void theRealFileTypeIsCheckedNotTheNameOrHeader() throws Exception {
        byte[] html = "<html><script>alert(1)</script></html>".getBytes(StandardCharsets.UTF_8);
        upload(ana, photoId, html, MediaType.IMAGE_JPEG_VALUE).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value(PhotoProcessor.NOT_AN_IMAGE));

        // Firma JPEG pero contenido dañado
        byte[] broken = { (byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0x00, 0x01, 0x02 };
        upload(ana, photoId, broken, MediaType.IMAGE_JPEG_VALUE).andExpect(status().isBadRequest());

        // Un PNG verdadero se acepta y se guarda como JPEG
        upload(ana, photoId, image("png", 20, 10), MediaType.APPLICATION_OCTET_STREAM_VALUE)
                .andExpect(status().isNoContent());
        byte[] stored = mvc.perform(get(imageUrl(photoId)).header("Authorization", ana.bearer()))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(PhotoProcessor.detectFormat(stored)).isEqualTo("jpeg");
    }

    @Test
    void sizeLimitsAreEnforced() throws Exception {
        byte[] big = new byte[(int) properties.maxSize().toBytes() + 1];
        big[0] = (byte) 0xFF;
        big[1] = (byte) 0xD8;
        big[2] = (byte) 0xFF;
        upload(ana, photoId, big, MediaType.IMAGE_JPEG_VALUE).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("La foto pesa más de 5 MB."));
    }

    @Test
    void photoOfUnknownOrDeletedRecordIsNotFound() throws Exception {
        upload(ana, UUID.randomUUID(), image("jpg", 8, 8), MediaType.IMAGE_JPEG_VALUE)
                .andExpect(status().isNotFound());

        upload(ana, photoId, image("jpg", 8, 8), MediaType.IMAGE_JPEG_VALUE).andExpect(status().isNoContent());
        Path file = properties.storageDir().resolve(photoId + ".jpg");
        assertThat(Files.exists(file)).isTrue();

        syncPhoto(ana, photoId, true);
        assertThat(Files.exists(file)).isFalse();
        mvc.perform(get(imageUrl(photoId)).header("Authorization", ana.bearer())).andExpect(status().isNotFound());
    }

    @Test
    void deletingTheAccountDeletesThePhotoFiles() throws Exception {
        upload(ana, photoId, image("jpg", 8, 8), MediaType.IMAGE_JPEG_VALUE).andExpect(status().isNoContent());
        Path file = properties.storageDir().resolve(photoId + ".jpg");
        assertThat(Files.exists(file)).isTrue();

        mvc.perform(delete("/api/auth/me").header("Authorization", ana.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"password\":\"" + TestUsers.PASSWORD + "\"}"))
                .andExpect(status().isNoContent());
        assertThat(Files.exists(file)).isFalse();
    }
}
