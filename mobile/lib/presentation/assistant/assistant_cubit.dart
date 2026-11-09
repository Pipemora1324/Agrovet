import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../data/photos/jpeg_metadata.dart';
import '../../data/photos/photo_capture.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/assistant_api.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../../domain/symptom_score.dart';

class AssistantState extends Equatable {
  const AssistantState({this.online = true, this.sending = false, this.photo, this.error});

  final bool online;
  final bool sending;

  /// Foto lista para enviar con la próxima pregunta (ya sin metadatos).
  final Uint8List? photo;
  final String? error;

  AssistantState copyWith({bool? online, bool? sending, Uint8List? Function()? photo, String? error}) =>
      AssistantState(
        online: online ?? this.online,
        sending: sending ?? this.sending,
        photo: photo == null ? this.photo : photo(),
        error: error,
      );

  @override
  List<Object?> get props => [online, sending, photo, error];
}

/// Conversación con el asistente sobre una vaca. Los mensajes se guardan en la base local; la lista
/// se lee directamente del repositorio.
class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit({
    required this.cowId,
    required this.api,
    required this.messages,
    required this.records,
    required this.inferences,
    required this.capture,
    required Stream<bool> connectivity,
    bool initiallyOnline = true,
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _now = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid(),
        super(AssistantState(online: initiallyOnline)) {
    _connection = connectivity.listen((online) => emit(state.copyWith(online: online)));
  }

  final String cowId;
  final AssistantApi api;
  final AssistantRepository messages;
  final RecordRepository records;
  final InferenceRepository inferences;
  final PhotoCapture capture;
  final DateTime Function() _now;
  final Uuid _uuid;
  late final StreamSubscription<bool> _connection;

  /// Mensajes anteriores que se envían para dar continuidad.
  static const historyTurns = 6;

  Future<void> attachPhoto(PhotoSource source) async {
    final result = await capture.pick(source);
    switch (result) {
      case Captured(:final bytes):
        try {
          emit(state.copyWith(photo: () => stripJpegMetadata(bytes)));
        } on FormatException {
          emit(state.copyWith(error: 'La foto no es una imagen JPEG válida.'));
        }
      case CaptureFailed(:final message):
        emit(state.copyWith(error: message));
      case CaptureCancelled():
        break;
    }
  }

  void removePhoto() => emit(state.copyWith(photo: () => null));

  /// Envía la pregunta. Devuelve true si se envió (para limpiar el campo de texto).
  Future<bool> send(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.sending) return false;
    if (!state.online) {
      emit(state.copyWith(error: 'Sin internet no se puede consultar al asistente. Vea los consejos de abajo.'));
      return false;
    }
    final photo = state.photo;
    final history = await messages.recentMessages(cowId, historyTurns);
    await messages.saveMessage(AssistantMessage(
      id: _uuid.v4(),
      cowId: cowId,
      fromUser: true,
      text: text,
      createdAt: _now(),
      withPhoto: photo != null,
    ));
    emit(state.copyWith(sending: true, photo: () => null));
    try {
      final answer = await api.ask(question: text, context: await _context(), history: history, photoJpeg: photo);
      await messages.saveMessage(
          AssistantMessage(id: _uuid.v4(), cowId: cowId, fromUser: false, text: answer, createdAt: _now()));
      emit(state.copyWith(sending: false));
    } on ApiException catch (e) {
      emit(state.copyWith(sending: false, error: e.message, photo: () => photo));
    }
    return true;
  }

  Future<void> clear() => messages.clearMessages(cowId);

  /// Último semáforo de la vaca y los síntomas del registro de hoy.
  Future<AssistantContext> _context() async {
    final latest = await inferences.watchLatest(cowId).first;
    final today = await records.recordFor(cowId, dateOnly(_now()));
    final assessment = today == null ? null : SymptomScore.assess(today);
    return AssistantContext(
      riskLevel: latest?.riskLevel,
      cause: latest?.cause,
      symptomScore: assessment?.score ?? latest?.symptomScore,
      probability: latest?.probability,
      symptoms: [for (final reason in assessment?.reasons ?? const []) reason.label],
    );
  }

  @override
  Future<void> close() async {
    await _connection.cancel();
    return super.close();
  }
}
