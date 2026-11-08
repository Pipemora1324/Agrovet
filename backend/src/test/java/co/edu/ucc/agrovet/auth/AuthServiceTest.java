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
import org.springframework.security.crypto.password.PasswordEncoder;

import co.edu.ucc.agrovet.auth.AuthDtos.LoginRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.RegisterRequest;
import co.edu.ucc.agrovet.auth.code.CodePurpose;
import co.edu.ucc.agrovet.auth.code.CodeRequestLimiter;
import co.edu.ucc.agrovet.auth.code.EmailCodeService;
import co.edu.ucc.agrovet.config.JwtProperties;
import co.edu.ucc.agrovet.mail.AccountMailer;
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
                mailer, props, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static User verifiedUser() {
        User user = new User("Ana", "ana@correo.co", "hash", NOW);
        user.markEmailVerified(NOW);
        return user;
    }

    @Test
    void registerOfVerifiedEmailOnlyWarnsTheOwner() {
        when(users.findByEmail("ana@correo.co")).thenReturn(Optional.of(verifiedUser()));
        service.register(new RegisterRequest("Otra", " ANA@correo.co ", "clave-segura"), "1.1.1.1");

        verify(mailer).sendAccountAlreadyExists("ana@correo.co", "Ana");
        verify(codes, never()).issue(any(), any());
        // La contraseña se procesa igual, para que el tiempo de respuesta no delate la cuenta
        verify(encoder).encode("clave-segura");
    }

    @Test
    void registerOfNewEmailCreatesUnverifiedUserAndSendsCode() {
        when(users.findByEmail("nuevo@correo.co")).thenReturn(Optional.empty());
        service.register(new RegisterRequest("Nuevo", "nuevo@correo.co", "clave-segura"), "1.1.1.1");

        verify(codeLimiter).acquire("1.1.1.1", "nuevo@correo.co", CodePurpose.VERIFY_EMAIL);
        verify(users).save(any(User.class));
        verify(mailer).sendVerificationCode("nuevo@correo.co", "Nuevo", "123456", Duration.ofMinutes(15));
    }

    @Test
    void dailyCodeLimitSkipsSendingWithoutError() {
        when(users.findByEmail("nuevo@correo.co")).thenReturn(Optional.empty());
        when(codes.canIssue(any(), eq(CodePurpose.VERIFY_EMAIL))).thenReturn(false);
        service.register(new RegisterRequest("Nuevo", "nuevo@correo.co", "clave-segura"), "1.1.1.1");
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

        assertThatThrownBy(() -> service.login(new LoginRequest("ana@correo.co", "clave"), "1.1.1.1"))
                .isInstanceOf(EmailNotVerifiedException.class);
        verify(tokenService, never()).createAccessToken(any(), any());
        // Ya tenía un código vigente: no se envía otro
        verify(codes, never()).issue(any(), any());
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
        RefreshToken expired = new RefreshToken(UUID.randomUUID(), UUID.randomUUID(), "h",
                NOW.minus(Duration.ofDays(15)), NOW.minusSeconds(1));
        when(refreshTokens.findByTokenHash(TokenService.hash("viejo"))).thenReturn(Optional.of(expired));

        assertThatThrownBy(() -> service.refresh("viejo")).isInstanceOf(AuthenticationFailedException.class);
        verify(refreshTokens, never()).revokeFamily(any(), any());
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
}
