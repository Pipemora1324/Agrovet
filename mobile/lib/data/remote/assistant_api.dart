import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities.dart';
import 'api_client.dart';

/// Contexto mínimo de la vaca que acompaña la pregunta. No lleva nombre ni datos de la persona.
class AssistantContext {
  const AssistantContext({this.riskLevel, this.cause, this.symptomScore, this.probability, this.symptoms = const []});

  final RiskLevel? riskLevel;
  final RiskCause? cause;
  final int? symptomScore;
  final double? probability;
  final List<String> symptoms;

  Map<String, dynamic> toJson() => {
        'riskLevel': riskLevel?.code,
        'cause': cause?.code,
        'symptomScore': symptomScore,
        'probability': probability,
        'symptoms': symptoms,
      };
}

/// Preguntas al asistente. La clave del proveedor de IA vive solo en el servidor.
class AssistantApi {
  AssistantApi(this._client);

  final ApiClient _client;

  Future<String> ask({
    required String question,
    AssistantContext? context,
    List<AssistantMessage> history = const [],
    Uint8List? photoJpeg,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>('/api/assistant/chat', data: {
        'question': question.trim(),
        'context': context?.toJson(),
        'history': [for (final m in history) {'fromUser': m.fromUser, 'text': m.text}],
        if (photoJpeg != null) 'photoBase64': base64Encode(photoJpeg),
      });
      return response.data!['answer'] as String;
    } catch (e) {
      throw ApiClient.describe(e);
    }
  }
}
