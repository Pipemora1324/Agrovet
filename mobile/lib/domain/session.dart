import 'package:equatable/equatable.dart';

/// Sesión del ganadero. Se guarda en el almacenamiento seguro para poder usar la app sin conexión,
/// junto con una copia del perfil para mostrarlo sin internet.
class Session extends Equatable {
  const Session({
    required this.userId,
    required this.name,
    required this.email,
    this.accessToken,
    this.refreshToken,
    this.isDemo = false,
    this.farmName,
    this.municipality,
    this.phone,
    this.privacyPolicyVersion,
  });

  /// Sesión local con datos de demostración (solo en modo debug).
  static const demoUserId = 'demo';

  final String userId;
  final String name;
  final String email;
  final String? accessToken;
  final String? refreshToken;
  final bool isDemo;
  final String? farmName;
  final String? municipality;
  final String? phone;

  /// Versión del aviso de privacidad aceptada (null en cuentas anteriores al aviso).
  final String? privacyPolicyVersion;

  /// Datos del usuario tal como los devuelve la API (/api/auth/me o el campo "user" de los tokens).
  factory Session.fromUser(Map<String, dynamic> user, {String? accessToken, String? refreshToken}) => Session(
        userId: user['id'] as String,
        name: user['name'] as String,
        email: user['email'] as String,
        accessToken: accessToken,
        refreshToken: refreshToken,
        farmName: user['farmName'] as String?,
        municipality: user['municipality'] as String?,
        phone: user['phone'] as String?,
        privacyPolicyVersion: user['privacyPolicyVersion'] as String?,
      );

  Session withTokens({required String accessToken, required String refreshToken}) =>
      _copy(accessToken: accessToken, refreshToken: refreshToken);

  /// Mismo usuario y tokens, con el perfil actualizado desde el servidor.
  Session withProfile(Session profile) => Session(
        userId: userId,
        name: profile.name,
        email: profile.email,
        accessToken: accessToken,
        refreshToken: refreshToken,
        isDemo: isDemo,
        farmName: profile.farmName,
        municipality: profile.municipality,
        phone: profile.phone,
        privacyPolicyVersion: profile.privacyPolicyVersion,
      );

  Session _copy({String? accessToken, String? refreshToken}) => Session(
        userId: userId,
        name: name,
        email: email,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        isDemo: isDemo,
        farmName: farmName,
        municipality: municipality,
        phone: phone,
        privacyPolicyVersion: privacyPolicyVersion,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'isDemo': isDemo,
        'farmName': farmName,
        'municipality': municipality,
        'phone': phone,
        'privacyPolicyVersion': privacyPolicyVersion,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        accessToken: json['accessToken'] as String?,
        refreshToken: json['refreshToken'] as String?,
        isDemo: json['isDemo'] as bool? ?? false,
        farmName: json['farmName'] as String?,
        municipality: json['municipality'] as String?,
        phone: json['phone'] as String?,
        privacyPolicyVersion: json['privacyPolicyVersion'] as String?,
      );

  @override
  List<Object?> get props =>
      [userId, name, email, accessToken, refreshToken, isDemo, farmName, municipality, phone, privacyPolicyVersion];
}
