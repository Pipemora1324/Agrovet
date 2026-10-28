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
import co.edu.ucc.agrovet.auth.AuthDtos.TokenResponse;
import co.edu.ucc.agrovet.auth.AuthDtos.UserResponse;
import co.edu.ucc.agrovet.common.ConflictException;
import co.edu.ucc.agrovet.common.NotFoundException;
import co.edu.ucc.agrovet.config.JwtProperties;
import co.edu.ucc.agrovet.user.User;
import co.edu.ucc.agrovet.user.UserRepository;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    static final String INVALID_CREDENTIALS = "Correo o contraseña incorrectos.";
    static final String INVALID_SESSION = "La sesión no es válida o expiró. Inicie sesión de nuevo.";

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokenService;
    private final LoginRateLimiter rateLimiter;
    private final JwtProperties jwtProperties;
    private final Clock clock;
    // Hash de relleno: si el correo no existe se compara igual, para no delatarlo por el tiempo de respuesta
    private final String dummyHash;

    public AuthService(UserRepository users, RefreshTokenRepository refreshTokens, PasswordEncoder passwordEncoder,
            TokenService tokenService, LoginRateLimiter rateLimiter, JwtProperties jwtProperties, Clock clock) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwordEncoder = passwordEncoder;
        this.tokenService = tokenService;
        this.rateLimiter = rateLimiter;
        this.jwtProperties = jwtProperties;
        this.clock = clock;
        this.dummyHash = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    @Transactional
    public TokenResponse register(RegisterRequest request) {
        String email = normalizeEmail(request.email());
        if (users.existsByEmail(email)) {
            throw new ConflictException("Ya existe una cuenta con ese correo.");
        }
        Instant now = clock.instant();
        User user = users.save(new User(request.name().trim(), email, passwordEncoder.encode(request.password()), now));
        return issueTokens(user, UUID.randomUUID(), now);
    }

    @Transactional
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
        return issueTokens(user.get(), UUID.randomUUID(), clock.instant());
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
