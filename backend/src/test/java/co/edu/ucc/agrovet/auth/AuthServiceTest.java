package co.edu.ucc.agrovet.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;

import co.edu.ucc.agrovet.auth.AuthDtos.ChangePasswordRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.LoginRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.RegisterRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.ResetPasswordRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.UpdateProfileRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.VerifyEmailRequest;
import co.edu.ucc.agrovet.auth.code.CodePurpose;
import co.edu.ucc.agrovet.auth.code.CodeRequestLimiter;
import co.edu.ucc.agrovet.auth.code.EmailCodeService;
import co.edu.ucc.agrovet.common.NotFoundException;
import co.edu.ucc.agrovet.config.JwtProperties;
import co.edu.ucc.agrovet.mail.AccountMailer;
import co.edu.ucc.agrovet.user.AccountDeletionService;
import co.edu.ucc.agrovet.user.User;
import co.edu.ucc.agrovet.user.UserRepository;

class AuthServiceTest {

    private static final Instant NOW = Instant.parse("2026-01-01T10:00:00Z");

    private final UserRepository users = mock(UserRepository.class);
    private final RefreshTokenRepository refreshTokens = mock(RefreshTokenRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final TokenService tokenService = mock(TokenService.class);
    private final LoginRateLimiter rateLimiter = mock(LoginRateLimiter.class);
    private final EmailCodeService codes = mock(EmailCodeService.class);
    private final CodeRequestLimiter codeLimiter = mock(CodeRequestLimiter.class);
    private final AccountMailer mailer = mock(AccountMailer.class);
    private final AccountDeletionService accountDeletion = mock(AccountDeletionService.class);
    private AuthService service;

    @BeforeEach
    void setUp() {
        when(encoder.encode(anyString())).thenReturn("hash");
        when(tokenService.newRefreshTokenValue()).thenReturn("nuevo-refresh");
        when(tokenService.createAccessToken(any(), any())).thenReturn("access");
        when(refreshTokens.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(users.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(codes.canIssue(any(), any())).thenReturn(true);
        when(codes.issue(any(), any())).thenReturn("123456");
        when(codes.ttl()).thenReturn(Duration.ofMinutes(15));
        JwtProperties props = new JwtProperties("x", "agrovet", Duration.ofMinutes(15), Duration.ofDays(14));
        service = new AuthService(users, refreshTokens, encoder, tokenService, rateLimiter, codes, codeLimiter,
                mailer, accountDeletion, props, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static User verifiedUser() {
        User user = new User("Ana", "ana@correo.co", "hash", NOW);
        user.markEmailVerified(NOW);
        return user;
    }

    @Test
    void registerOfVerifiedEmailOnlyWarnsTheOwner() {
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(verifiedUser()));
        service.register(new RegisterRequest("Otra", " ANA@correo.co ", "clave-segura", true, "2026-11"), "1.1.1.1");

        verify(mailer).sendAccountAlreadyExists("ana@correo.co", "Ana");
        verify(codes, never()).issue(any(), any());
        // La contraseña se procesa igual, para que el tiempo de respuesta no delate la cuenta
        verify(encoder).encode("clave-segura");
    }

    @Test
    void registerOfNewEmailCreatesUnverifiedUserAndSendsCode() {
        when(users.findByEmail("nuevo@correo.co")).thenReturn(Optional.empty());
        service.register(new RegisterRequest("Nuevo", "nuevo@correo.co", "clave-segura", true, "2026-11"), "1.1.1.1");

        verify(codeLimiter).acquire("1.1.1.1", "nuevo@correo.co", CodePurpose.VERIFY_EMAIL);
        verify(users).save(any(User.class));
        verify(mailer).sendVerificationCode("nuevo@correo.co", "Nuevo", "123456", Duration.ofMinutes(15));
    }

    @Test
    void dailyCodeLimitSkipsSendingWithoutError() {
        when(users.findByEmail("nuevo@correo.co")).thenReturn(Optional.empty());
        when(codes.canIssue(any(), eq(CodePurpose.VERIFY_EMAIL))).thenReturn(false);
        service.register(new RegisterRequest("Nuevo", "nuevo@correo.co", "clave-segura", true, "2026-11"), "1.1.1.1");
        verify(codes, never()).issue(any(), any());
        verify(mailer, never()).sendVerificationCode(anyString(), anyString(), anyString(), any());
    }

    @Test
    void loginWithUnknownEmailStillComparesPassword() {
        when(users.findByEmail("nadie@correo.co")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.login(new LoginRequest("nadie@correo.co", "x"), "1.1.1.1"))
                .isInstanceOf(AuthenticationFailedException.class);
        verify(encoder).matches(eq("x"), anyString());
        verify(rateLimiter).registerAttempt("1.1.1.1", "nadie@correo.co");
        verify(rateLimiter, never()).reset(anyString(), anyString());
    }

    @Test
    void loginOfUnverifiedUserIsRefusedWithoutTokens() {
        User user = new User("Ana", "ana@correo.co", "hash", NOW);
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(user));
        when(encoder.matches("clave", "hash")).thenReturn(true);
        when(codes.hasActiveCode(user.getId(), CodePurpose.VERIFY_EMAIL)).thenReturn(true);
        when(codeLimiter.tryAcquire(any(), any(), any())).thenReturn(true);

        assertThatThrownBy(() -> service.login(new LoginRequest("ana@correo.co", "clave"), "1.1.1.1"))
                .isInstanceOf(EmailNotVerifiedException.class);
        verify(tokenService, never()).createAccessToken(any(), any());
        // Ya tenía un código vigente: no se envía otro ni se gasta un turno del límite
        verify(codes, never()).issue(any(), any());
        verify(codeLimiter, never()).tryAcquire(any(), any(), any());
    }

    @Test
    void reusedRefreshTokenRevokesWholeFamily() {
        RefreshToken used = new RefreshToken(UUID.randomUUID(), UUID.randomUUID(), "h", NOW.minusSeconds(60),
                NOW.plus(Duration.ofDays(1)));
        used.markReplaced(UUID.randomUUID(), NOW.minusSeconds(30));
        when(refreshTokens.findByTokenHash(TokenService.hash("robado"))).thenReturn(Optional.of(used));

        assertThatThrownBy(() -> service.refresh("robado")).isInstanceOf(AuthenticationFailedException.class);
        verify(refreshTokens).revokeFamily(used.getFamilyId(), NOW);
    }

    @Test
    void expiredRefreshTokenIsRejected() {
        // El usuario existe y está verificado: solo el vencimiento puede rechazarlo
        User user = verifiedUser();
        when(users.findById(user.getId())).thenReturn(Optional.of(user));
        RefreshToken expired = new RefreshToken(user.getId(), UUID.randomUUID(), "h",
                NOW.minus(Duration.ofDays(15)), NOW);
        when(refreshTokens.findByTokenHash(TokenService.hash("viejo"))).thenReturn(Optional.of(expired));

        assertThatThrownBy(() -> service.refresh("viejo")).isInstanceOf(AuthenticationFailedException.class);
        verify(refreshTokens, never()).revokeFamily(any(), any());
        verify(refreshTokens, never()).save(any());
    }

    @Test
    void unknownEmailIsRefusedEvenIfThePasswordCheckPassed() {
        // Defensa en profundidad: aunque el hash de relleno coincidiera, sin cuenta no hay sesión
        when(users.findByEmail("nadie@correo.co")).thenReturn(Optional.empty());
        when(encoder.matches(anyString(), anyString())).thenReturn(true);

        assertThatThrownBy(() -> service.login(new LoginRequest("nadie@correo.co", "x"), "1.1.1.1"))
                .isInstanceOf(AuthenticationFailedException.class)
                .hasMessage(AuthService.INVALID_CREDENTIALS);
    }

    @Test
    void refreshRotatesToken() {
        User user = verifiedUser();
        RefreshToken current = new RefreshToken(user.getId(), UUID.randomUUID(), "h", NOW.minusSeconds(60),
                NOW.plus(Duration.ofDays(1)));
        when(refreshTokens.findByTokenHash(TokenService.hash("vigente"))).thenReturn(Optional.of(current));
        when(users.findById(user.getId())).thenReturn(Optional.of(user));

        var response = service.refresh("vigente");

        assertThat(response.refreshToken()).isEqualTo("nuevo-refresh");
        assertThat(current.isRevoked()).isTrue();
        assertThat(current.getReplacedBy()).isNotNull();
    }

    @Test
    void hashIsDeterministicSha256() {
        assertThat(TokenService.hash("abc"))
                .isEqualTo("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    }

    // ---- Registro sobre una cuenta sin verificar ----

    @Test
    void registerOverUnverifiedAccountReplacesItAndRecordsConsent() {
        User pending = new User("Viejo", "ana@correo.co", "hash-viejo", NOW.minusSeconds(600));
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(pending));
        when(encoder.encode("clave-nueva")).thenReturn("hash-nuevo");

        service.register(new RegisterRequest("  Ana  ", "ana@correo.co", "clave-nueva", true, " 2026-11 "), "1.1.1.1");

        assertThat(pending.getName()).isEqualTo("Ana");
        assertThat(pending.getPasswordHash()).isEqualTo("hash-nuevo");
        assertThat(pending.getPrivacyPolicyVersion()).isEqualTo("2026-11");
        assertThat(pending.getPrivacyAcceptedAt()).isEqualTo(NOW);
        verify(users, never()).save(any());
        verify(mailer).sendVerificationCode("ana@correo.co", "Ana", "123456", Duration.ofMinutes(15));
    }

    // ---- Login ----

    @Test
    void successfulLoginResetsTheCounterAndIssuesTokens() {
        User user = verifiedUser();
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(user));
        when(encoder.matches("clave", "hash")).thenReturn(true);
        when(tokenService.accessTtlSeconds()).thenReturn(900L);

        var response = service.login(new LoginRequest(" Ana@Correo.co ", "clave"), "1.1.1.1");

        verify(rateLimiter).registerAttempt("1.1.1.1", "ana@correo.co");
        verify(rateLimiter).reset("1.1.1.1", "ana@correo.co");
        assertThat(response.accessToken()).isEqualTo("access");
        assertThat(response.refreshToken()).isEqualTo("nuevo-refresh");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.expiresIn()).isEqualTo(900L);
        assertThat(response.user().email()).isEqualTo("ana@correo.co");
        ArgumentCaptor<RefreshToken> saved = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokens).save(saved.capture());
        assertThat(saved.getValue().getUserId()).isEqualTo(user.getId());
        assertThat(saved.getValue().isExpired(NOW.plus(Duration.ofDays(14)).minusSeconds(1))).isFalse();
        assertThat(saved.getValue().isExpired(NOW.plus(Duration.ofDays(14)))).isTrue();
    }

    @Test
    void wrongPasswordOfExistingUserIsRefusedWithTheSameMessage() {
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(verifiedUser()));
        when(encoder.matches("mala", "hash")).thenReturn(false);

        assertThatThrownBy(() -> service.login(new LoginRequest("ana@correo.co", "mala"), "1.1.1.1"))
                .isInstanceOf(AuthenticationFailedException.class)
                .hasMessage(AuthService.INVALID_CREDENTIALS);
        verify(rateLimiter, never()).reset(anyString(), anyString());
        verify(refreshTokens, never()).save(any());
    }

    @Test
    void unverifiedLoginSendsACodeOnlyIfNoneIsActiveAndTheLimiterAllows() {
        User user = new User("Ana", "ana@correo.co", "hash", NOW);
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(user));
        when(encoder.matches("clave", "hash")).thenReturn(true);
        when(codes.hasActiveCode(user.getId(), CodePurpose.VERIFY_EMAIL)).thenReturn(false);
        when(codeLimiter.tryAcquire("1.1.1.1", "ana@correo.co", CodePurpose.VERIFY_EMAIL)).thenReturn(true, false);

        assertThatThrownBy(() -> service.login(new LoginRequest("ana@correo.co", "clave"), "1.1.1.1"))
                .isInstanceOf(EmailNotVerifiedException.class);
        assertThatThrownBy(() -> service.login(new LoginRequest("ana@correo.co", "clave"), "1.1.1.1"))
                .isInstanceOf(EmailNotVerifiedException.class);

        // Solo el primer intento envía: el segundo choca con la espera entre envíos
        verify(mailer).sendVerificationCode("ana@correo.co", "Ana", "123456", Duration.ofMinutes(15));
        verify(refreshTokens, never()).save(any());
    }

    // ---- Verificación del correo ----

    @Test
    void rightCodeVerifiesTheEmailAndOpensASession() {
        User user = new User("Ana", "ana@correo.co", "hash", NOW.minusSeconds(60));
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(user));
        when(codes.verify(user.getId(), CodePurpose.VERIFY_EMAIL, "123456")).thenReturn(true);

        var response = service.verifyEmail(new VerifyEmailRequest(" ANA@correo.co", "123456"));

        assertThat(user.isEmailVerified()).isTrue();
        assertThat(response.refreshToken()).isEqualTo("nuevo-refresh");
        verify(refreshTokens).save(any());
    }

    @Test
    void wrongCodeUnknownEmailOrVerifiedAccountAreAllInvalidCode() {
        User pending = new User("Ana", "ana@correo.co", "hash", NOW);
        User verified = verifiedUser();
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(pending));
        when(users.findByEmail("beto@correo.co")).thenReturn(Optional.of(verified));
        when(users.findByEmail("nadie@correo.co")).thenReturn(Optional.empty());
        // Aunque el código de la cuenta ya verificada fuera correcto, no se abre otra sesión por aquí
        when(codes.verify(verified.getId(), CodePurpose.VERIFY_EMAIL, "123456")).thenReturn(true);

        assertThatThrownBy(() -> service.verifyEmail(new VerifyEmailRequest("ana@correo.co", "000000")))
                .isInstanceOf(InvalidCodeException.class);
        assertThatThrownBy(() -> service.verifyEmail(new VerifyEmailRequest("beto@correo.co", "123456")))
                .isInstanceOf(InvalidCodeException.class);
        assertThatThrownBy(() -> service.verifyEmail(new VerifyEmailRequest("nadie@correo.co", "123456")))
                .isInstanceOf(InvalidCodeException.class);
        assertThat(pending.isEmailVerified()).isFalse();
        verify(refreshTokens, never()).save(any());
    }

    @Test
    void resendGoesOnlyToUnverifiedAccountsButAlwaysCountsTheRequest() {
        User pending = new User("Ana", "ana@correo.co", "hash", NOW);
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(pending));
        when(users.findByEmail("beto@correo.co")).thenReturn(Optional.of(verifiedUser()));

        service.resendVerificationCode(" ana@correo.co ", "1.1.1.1");
        service.resendVerificationCode("beto@correo.co", "1.1.1.1");
        service.resendVerificationCode("nadie@correo.co", "1.1.1.1");

        verify(codeLimiter).acquire("1.1.1.1", "ana@correo.co", CodePurpose.VERIFY_EMAIL);
        verify(codeLimiter).acquire("1.1.1.1", "beto@correo.co", CodePurpose.VERIFY_EMAIL);
        verify(codeLimiter).acquire("1.1.1.1", "nadie@correo.co", CodePurpose.VERIFY_EMAIL);
        verify(mailer).sendVerificationCode("ana@correo.co", "Ana", "123456", Duration.ofMinutes(15));
        verify(codes).issue(pending.getId(), CodePurpose.VERIFY_EMAIL);
    }

    // ---- Recuperación de contraseña ----

    @Test
    void passwordResetCodeIsSentOnlyIfTheAccountExists() {
        User user = verifiedUser();
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(user));

        service.requestPasswordReset("ANA@correo.co", "1.1.1.1");
        service.requestPasswordReset("nadie@correo.co", "1.1.1.1");

        verify(codeLimiter).acquire("1.1.1.1", "ana@correo.co", CodePurpose.RESET_PASSWORD);
        verify(codeLimiter).acquire("1.1.1.1", "nadie@correo.co", CodePurpose.RESET_PASSWORD);
        verify(mailer).sendPasswordResetCode("ana@correo.co", "Ana", "123456", Duration.ofMinutes(15));
        verify(mailer, never()).sendVerificationCode(anyString(), anyString(), anyString(), any());
    }

    @Test
    void resetWithRightCodeChangesPasswordVerifiesAndClosesSessions() {
        User user = new User("Ana", "ana@correo.co", "hash-viejo", NOW);
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(user));
        when(codes.verify(user.getId(), CodePurpose.RESET_PASSWORD, "654321")).thenReturn(true);
        when(encoder.encode("clave-nueva")).thenReturn("hash-nuevo");

        service.resetPassword(new ResetPasswordRequest("ana@correo.co", "654321", "clave-nueva"));

        assertThat(user.getPasswordHash()).isEqualTo("hash-nuevo");
        assertThat(user.isEmailVerified()).isTrue();
        verify(refreshTokens).revokeAllForUser(user.getId(), NOW);
    }

    @Test
    void resetWithWrongCodeOrUnknownEmailChangesNothing() {
        User user = new User("Ana", "ana@correo.co", "hash-viejo", NOW);
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(user));

        assertThatThrownBy(() -> service.resetPassword(new ResetPasswordRequest("ana@correo.co", "000000", "x")))
                .isInstanceOf(InvalidCodeException.class);
        assertThatThrownBy(() -> service.resetPassword(new ResetPasswordRequest("nadie@correo.co", "000000", "x")))
                .isInstanceOf(InvalidCodeException.class);
        assertThat(user.getPasswordHash()).isEqualTo("hash-viejo");
        assertThat(user.isEmailVerified()).isFalse();
        verify(refreshTokens, never()).revokeAllForUser(any(), any());
    }

    // ---- Perfil, contraseña y borrado (con la sesión abierta) ----

    @Test
    void profileUpdateTrimsAndTurnsBlanksIntoNull() {
        User user = verifiedUser();
        when(users.findById(user.getId())).thenReturn(Optional.of(user));

        var response = service.updateProfile(user.getId(),
                new UpdateProfileRequest(" Ana María ", "  ", " Pasto ", null));

        assertThat(user.getName()).isEqualTo("Ana María");
        assertThat(user.getFarmName()).isNull();
        assertThat(user.getMunicipality()).isEqualTo("Pasto");
        assertThat(user.getPhone()).isNull();
        assertThat(response.name()).isEqualTo("Ana María");
        assertThat(response.municipality()).isEqualTo("Pasto");
    }

    @Test
    void privacyPolicyAcceptanceIsRecorded() {
        User user = verifiedUser();
        when(users.findById(user.getId())).thenReturn(Optional.of(user));

        var response = service.acceptPrivacyPolicy(user.getId(), " 2026-12 ");

        assertThat(response.privacyPolicyVersion()).isEqualTo("2026-12");
        assertThat(response.privacyAcceptedAt()).isEqualTo(NOW);
    }

    @Test
    void unknownUserIsNotFound() {
        UUID id = UUID.randomUUID();
        when(users.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.currentUser(id)).isInstanceOf(NotFoundException.class)
                .hasMessage("El usuario no existe.");
        assertThatThrownBy(() -> service.updateProfile(id, new UpdateProfileRequest("A", null, null, null)))
                .isInstanceOf(NotFoundException.class);
    }

    @Test
    void currentUserIsReturned() {
        User user = verifiedUser();
        when(users.findById(user.getId())).thenReturn(Optional.of(user));

        assertThat(service.currentUser(user.getId()).email()).isEqualTo("ana@correo.co");
    }

    @Test
    void changePasswordClosesEverySessionAndOpensANewOne() {
        User user = verifiedUser();
        when(users.findById(user.getId())).thenReturn(Optional.of(user));
        when(encoder.matches("actual", "hash")).thenReturn(true);
        when(encoder.encode("nueva-clave")).thenReturn("hash-nuevo");

        var response = service.changePassword(user.getId(), new ChangePasswordRequest("actual", "nueva-clave"),
                "1.1.1.1");

        assertThat(user.getPasswordHash()).isEqualTo("hash-nuevo");
        verify(rateLimiter).registerAttempt("1.1.1.1", "ana@correo.co");
        verify(rateLimiter).reset("1.1.1.1", "ana@correo.co");
        verify(refreshTokens).revokeAllForUser(user.getId(), NOW);
        assertThat(response.refreshToken()).isEqualTo("nuevo-refresh");
    }

    @Test
    void wrongCurrentPasswordBlocksChangeAndDeletion() {
        User user = verifiedUser();
        when(users.findById(user.getId())).thenReturn(Optional.of(user));
        when(encoder.matches("mala", "hash")).thenReturn(false);

        assertThatThrownBy(() -> service.changePassword(user.getId(), new ChangePasswordRequest("mala", "nueva"),
                "1.1.1.1")).isInstanceOf(AuthenticationFailedException.class).hasMessage(AuthService.WRONG_PASSWORD);
        assertThatThrownBy(() -> service.deleteAccount(user.getId(), "mala", "1.1.1.1"))
                .isInstanceOf(AuthenticationFailedException.class);

        assertThat(user.getPasswordHash()).isEqualTo("hash");
        verify(rateLimiter, never()).reset(anyString(), anyString());
        verify(refreshTokens, never()).revokeAllForUser(any(), any());
        verify(accountDeletion, never()).deleteEverything(any());
    }

    @Test
    void deleteAccountWithRightPasswordDeletesEverything() {
        User user = verifiedUser();
        when(users.findById(user.getId())).thenReturn(Optional.of(user));
        when(encoder.matches("clave", "hash")).thenReturn(true);

        service.deleteAccount(user.getId(), "clave", "1.1.1.1");

        verify(accountDeletion).deleteEverything(user.getId());
    }

    // ---- Refresh y logout ----

    @Test
    void unknownRefreshTokenIsRejected() {
        when(refreshTokens.findByTokenHash(any())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.refresh("inventado")).isInstanceOf(AuthenticationFailedException.class)
                .hasMessage(AuthService.INVALID_SESSION);
    }

    @Test
    void refreshOfUnverifiedOrMissingUserIsRejected() {
        User pending = new User("Ana", "ana@correo.co", "hash", NOW);
        RefreshToken token = new RefreshToken(pending.getId(), UUID.randomUUID(), "h", NOW.minusSeconds(60),
                NOW.plus(Duration.ofDays(1)));
        when(refreshTokens.findByTokenHash(TokenService.hash("t"))).thenReturn(Optional.of(token));
        when(users.findById(pending.getId())).thenReturn(Optional.of(pending));

        assertThatThrownBy(() -> service.refresh("t")).isInstanceOf(AuthenticationFailedException.class);
        assertThat(token.isRevoked()).isFalse();
        verify(refreshTokens, never()).save(any());
    }

    @Test
    void rotatedTokenKeepsTheFamilyAndAFreshExpiry() {
        User user = verifiedUser();
        UUID family = UUID.randomUUID();
        RefreshToken current = new RefreshToken(user.getId(), family, "h", NOW.minusSeconds(60),
                NOW.plusSeconds(1));
        when(refreshTokens.findByTokenHash(TokenService.hash("vigente"))).thenReturn(Optional.of(current));
        when(users.findById(user.getId())).thenReturn(Optional.of(user));

        service.refresh("vigente");

        ArgumentCaptor<RefreshToken> saved = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokens).save(saved.capture());
        RefreshToken next = saved.getValue();
        assertThat(next.getFamilyId()).isEqualTo(family);
        assertThat(next.getUserId()).isEqualTo(user.getId());
        assertThat(next.isExpired(NOW.plus(Duration.ofDays(14)).minusSeconds(1))).isFalse();
        assertThat(current.getReplacedBy()).isEqualTo(next.getId());
        verify(refreshTokens, never()).revokeFamily(any(), any());
    }

    @Test
    void logoutRevokesTheFamilyOfAKnownToken() {
        RefreshToken token = new RefreshToken(UUID.randomUUID(), UUID.randomUUID(), "h", NOW, NOW.plusSeconds(60));
        when(refreshTokens.findByTokenHash(TokenService.hash("mio"))).thenReturn(Optional.of(token));

        service.logout("mio");
        service.logout("desconocido");

        verify(refreshTokens).revokeFamily(token.getFamilyId(), NOW);
    }

    @Test
    void emailIsTrimmedAndLowercased() {
        assertThat(AuthService.normalizeEmail("  Ana.Pérez@Correo.CO ")).isEqualTo("ana.pérez@correo.co");
    }
}
