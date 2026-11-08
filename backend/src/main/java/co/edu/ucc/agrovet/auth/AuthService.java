package co.edu.ucc.agrovet.auth;

import java.time.Clock;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import co.edu.ucc.agrovet.auth.AuthDtos.LoginRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.RegisterRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.ResetPasswordRequest;
import co.edu.ucc.agrovet.auth.AuthDtos.TokenResponse;
import co.edu.ucc.agrovet.auth.AuthDtos.UserResponse;
import co.edu.ucc.agrovet.auth.AuthDtos.VerifyEmailRequest;
import co.edu.ucc.agrovet.auth.code.CodePurpose;
import co.edu.ucc.agrovet.auth.code.CodeRequestLimiter;
import co.edu.ucc.agrovet.auth.code.EmailCodeService;
import co.edu.ucc.agrovet.common.NotFoundException;
import co.edu.ucc.agrovet.config.JwtProperties;
import co.edu.ucc.agrovet.mail.AccountMailer;
import co.edu.ucc.agrovet.user.User;
import co.edu.ucc.agrovet.user.UserRepository;

/**
 * Cuentas y sesiones.
 * <p>
 * Registro, reenvío y recuperación responden siempre igual, exista o no el correo; los correos salen
 * en segundo plano. Solo el login con la contraseña correcta revela que falta verificar el correo.
 */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    static final String INVALID_CREDENTIALS = "Correo o contraseña incorrectos.";
    static final String INVALID_SESSION = "La sesión no es válida o expiró. Inicie sesión de nuevo.";
    public static final String CODE_SENT = "Si el correo es correcto, le llegará un código de 6 números. "
            + "Revise también la carpeta de correo no deseado.";

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokenService;
    private final LoginRateLimiter rateLimiter;
    private final EmailCodeService codes;
    private final CodeRequestLimiter codeLimiter;
    private final AccountMailer mailer;
    private final JwtProperties jwtProperties;
    private final Clock clock;
    // Hash de relleno: si el correo no existe se compara igual, para no delatarlo por el tiempo de respuesta
    private final String dummyHash;

    public AuthService(UserRepository users, RefreshTokenRepository refreshTokens, PasswordEncoder passwordEncoder,
            TokenService tokenService, LoginRateLimiter rateLimiter, EmailCodeService codes,
            CodeRequestLimiter codeLimiter, AccountMailer mailer, JwtProperties jwtProperties, Clock clock) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwordEncoder = passwordEncoder;
        this.tokenService = tokenService;
        this.rateLimiter = rateLimiter;
        this.codes = codes;
        this.codeLimiter = codeLimiter;
        this.mailer = mailer;
        this.jwtProperties = jwtProperties;
        this.clock = clock;
        this.dummyHash = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    /**
     * Crea la cuenta sin verificar y envía el código. Si el correo ya tiene una cuenta verificada,
     * solo se avisa a su dueño por correo; la respuesta es la misma en ambos casos.
     */
    @Transactional
    public void register(RegisterRequest request, String clientIp) {
        String email = normalizeEmail(request.email());
        codeLimiter.acquire(clientIp, email, CodePurpose.VERIFY_EMAIL);
        // Se calcula siempre, para que el tiempo de respuesta no dependa de si la cuenta existe
        String hash = passwordEncoder.encode(request.password());
        Instant now = clock.instant();

        Optional<User> existing = users.findByEmail(email);
        if (existing.isPresent() && existing.get().isEmailVerified()) {
            mailer.sendAccountAlreadyExists(email, existing.get().getName());
            return;
        }
        String name = request.name().trim();
        User user = existing.map(u -> {
            u.replaceUnverifiedRegistration(name, hash, now);
            return u;
        }).orElseGet(() -> users.save(new User(name, email, hash, now)));
        sendCode(user, CodePurpose.VERIFY_EMAIL);
    }

    /** El código correcto verifica el correo y abre la sesión. */
    @Transactional(noRollbackFor = InvalidCodeException.class)
    public TokenResponse verifyEmail(VerifyEmailRequest request) {
        User user = users.findByEmail(normalizeEmail(request.email()))
                .filter(u -> !u.isEmailVerified())
                .orElseThrow(InvalidCodeException::new);
        if (!codes.verify(user.getId(), CodePurpose.VERIFY_EMAIL, request.code())) {
            throw new InvalidCodeException();
        }
        Instant now = clock.instant();
        user.markEmailVerified(now);
        return issueTokens(user, UUID.randomUUID(), now);
    }

    @Transactional
    public void resendVerificationCode(String rawEmail, String clientIp) {
        String email = normalizeEmail(rawEmail);
        codeLimiter.acquire(clientIp, email, CodePurpose.VERIFY_EMAIL);
        users.findByEmail(email)
                .filter(u -> !u.isEmailVerified())
                .ifPresent(u -> sendCode(u, CodePurpose.VERIFY_EMAIL));
    }

    // Si falta verificar, el código emitido debe quedar guardado aunque la respuesta sea un error
    @Transactional(noRollbackFor = EmailNotVerifiedException.class)
    public TokenResponse login(LoginRequest request, String clientIp) {
        String email = normalizeEmail(request.email());
        rateLimiter.registerAttempt(clientIp, email);

        Optional<User> user = users.findByEmail(email);
        String hash = user.map(User::getPasswordHash).orElse(dummyHash);
        boolean matches = passwordEncoder.matches(request.password(), hash);
        if (user.isEmpty() || !matches) {
            throw new AuthenticationFailedException(INVALID_CREDENTIALS);
        }
        rateLimiter.reset(clientIp, email);
        User account = user.get();
        if (!account.isEmailVerified()) {
            // Si no tiene un código vigente se le envía uno, respetando la espera entre envíos
            if (!codes.hasActiveCode(account.getId(), CodePurpose.VERIFY_EMAIL)
                    && codeLimiter.tryAcquire(clientIp, email, CodePurpose.VERIFY_EMAIL)) {
                sendCode(account, CodePurpose.VERIFY_EMAIL);
            }
            throw new EmailNotVerifiedException();
        }
        return issueTokens(account, UUID.randomUUID(), clock.instant());
    }

    @Transactional
    public void requestPasswordReset(String rawEmail, String clientIp) {
        String email = normalizeEmail(rawEmail);
        codeLimiter.acquire(clientIp, email, CodePurpose.RESET_PASSWORD);
        users.findByEmail(email).ifPresent(u -> sendCode(u, CodePurpose.RESET_PASSWORD));
    }

    /**
     * Cambia la contraseña con el código del correo y cierra todas las sesiones abiertas. Como el
     * código demuestra que la persona recibe ese correo, la cuenta queda verificada.
     */
    @Transactional(noRollbackFor = InvalidCodeException.class)
    public void resetPassword(ResetPasswordRequest request) {
        User user = users.findByEmail(normalizeEmail(request.email())).orElseThrow(InvalidCodeException::new);
        if (!codes.verify(user.getId(), CodePurpose.RESET_PASSWORD, request.code())) {
            throw new InvalidCodeException();
        }
        Instant now = clock.instant();
        user.changePassword(passwordEncoder.encode(request.newPassword()), now);
        user.markEmailVerified(now);
        int closed = refreshTokens.revokeAllForUser(user.getId(), now);
        log.info("Contraseña restablecida para el usuario {}; {} sesiones cerradas", user.getId(), closed);
    }

    /**
     * Rotación: cada refresh token sirve una sola vez. Si llega uno ya usado, se asume robo y se
     * revoca toda la familia (el atacante y el usuario legítimo deben volver a iniciar sesión).
     */
    @Transactional(noRollbackFor = AuthenticationFailedException.class)
    public TokenResponse refresh(String refreshToken) {
        Instant now = clock.instant();
        RefreshToken current = refreshTokens.findByTokenHash(TokenService.hash(refreshToken))
                .orElseThrow(() -> new AuthenticationFailedException(INVALID_SESSION));

        if (current.isRevoked()) {
            int revoked = refreshTokens.revokeFamily(current.getFamilyId(), now);
            log.warn("Reuso de refresh token detectado: familia {} revocada ({} tokens activos)",
                    current.getFamilyId(), revoked);
            throw new AuthenticationFailedException(INVALID_SESSION);
        }
        if (current.isExpired(now)) {
            throw new AuthenticationFailedException(INVALID_SESSION);
        }

        User user = users.findById(current.getUserId())
                .filter(User::isEmailVerified)
                .orElseThrow(() -> new AuthenticationFailedException(INVALID_SESSION));
        String newValue = tokenService.newRefreshTokenValue();
        RefreshToken next = refreshTokens.save(new RefreshToken(user.getId(), current.getFamilyId(),
                TokenService.hash(newValue), now, now.plus(jwtProperties.refreshTtl())));
        current.markReplaced(next.getId(), now);
        return response(user, newValue, now);
    }

    @Transactional
    public void logout(String refreshToken) {
        refreshTokens.findByTokenHash(TokenService.hash(refreshToken))
                .ifPresent(token -> refreshTokens.revokeFamily(token.getFamilyId(), clock.instant()));
    }

    @Transactional(readOnly = true)
    public UserResponse currentUser(UUID userId) {
        return users.findById(userId).map(UserResponse::from)
                .orElseThrow(() -> new NotFoundException("El usuario no existe."));
    }

    /** Emite y envía un código, salvo que la cuenta ya haya pedido el máximo del día. */
    private void sendCode(User user, CodePurpose purpose) {
        if (!codes.canIssue(user.getId(), purpose)) {
            log.warn("Usuario {}: se alcanzó el máximo diario de códigos ({})", user.getId(), purpose);
            return;
        }
        String code = codes.issue(user.getId(), purpose);
        switch (purpose) {
            case VERIFY_EMAIL -> mailer.sendVerificationCode(user.getEmail(), user.getName(), code, codes.ttl());
            case RESET_PASSWORD -> mailer.sendPasswordResetCode(user.getEmail(), user.getName(), code, codes.ttl());
        }
    }

    private TokenResponse issueTokens(User user, UUID familyId, Instant now) {
        String refreshValue = tokenService.newRefreshTokenValue();
        refreshTokens.save(new RefreshToken(user.getId(), familyId, TokenService.hash(refreshValue), now,
                now.plus(jwtProperties.refreshTtl())));
        return response(user, refreshValue, now);
    }

    private TokenResponse response(User user, String refreshValue, Instant now) {
        return new TokenResponse(tokenService.createAccessToken(user, now), refreshValue, "Bearer",
                tokenService.accessTtlSeconds(), UserResponse.from(user));
    }

    static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
