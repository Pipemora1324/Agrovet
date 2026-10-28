import 'package:equatable/equatable.dart';

/// Sesión del ganadero. Se guarda en el almacenamiento seguro para poder usar la app sin conexión.
class Session extends Equatable {
  const Session({
    required this.userId,
    required this.name,
    required this.email,
    this.accessToken,
    this.refreshToken,
    this.isDemo = false,
  });

  /// Sesión local con datos de demostración (solo en modo debug).
  static const demoUserId = 'demo';

  final String userId;
  final String name;
  final String email;
  final String? accessToken;
  final String? refreshToken;
  final bool isDemo;

  Session withTokens({required String accessToken, required String refreshToken}) => Session(
        userId: userId,
        name: name,
        email: email,
        accessToken: accessToken,
        refreshToken: refreshToken,
        isDemo: isDemo,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'isDemo': isDemo,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        accessToken: json['accessToken'] as String?,
        refreshToken: json['refreshToken'] as String?,
        isDemo: json['isDemo'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [userId, name, email, accessToken, refreshToken, isDemo];
}
