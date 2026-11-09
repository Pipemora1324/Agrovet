import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities.dart';
import '../../domain/record_estimates.dart';
import '../../domain/repositories.dart';

/// Preguntas del registro, en orden. La leche se salta si la vaca no está en ordeño.
enum RecordStep { feed, milk, body, udder, done }

class DailyRecordState extends Equatable {
  const DailyRecordState({
    required this.date,
    this.loading = true,
    this.existing,
    this.step = RecordStep.feed,
    this.answers = const RecordAnswers(),
    this.baselines,
    this.saving = false,
    this.saved = false,
    this.milking = true,
  });

  final DateTime date;
  final bool loading;

  /// Registro ya guardado para ese día (se reemplaza en lugar de duplicarlo).
  final DailyRecord? existing;
  final RecordStep step;
  final RecordAnswers answers;

  /// Línea base de la vaca (null mientras carga).
  final RecordBaselines? baselines;
  final bool saving;
  final bool saved;

  /// La vaca está en ordeño (si no, no se pregunta por la leche).
  final bool milking;

  List<RecordStep> get steps => [
        RecordStep.feed,
        if (milking) RecordStep.milk,
        RecordStep.body,
        RecordStep.udder,
      ];

  /// Avance de 0 a 1 para la barra de progreso.
  double get progress => step == RecordStep.done ? 1 : steps.indexOf(step) / steps.length;

  /// Número de la pregunta actual (desde 1).
  int get questionNumber => steps.indexOf(step) + 1;

  /// Valores que se guardarán, con su origen.
  RecordEstimate get estimate => baselines == null
      ? const RecordEstimate()
      : RecordEstimator.estimate(answers, baselines!, milking: milking);

  DailyRecordState copyWith({
    bool? loading,
    DailyRecord? Function()? existing,
    RecordStep? step,
    RecordAnswers? answers,
    RecordBaselines? baselines,
    bool? saving,
    bool? saved,
  }) =>
      DailyRecordState(
        date: date,
        loading: loading ?? this.loading,
        existing: existing == null ? this.existing : existing(),
        step: step ?? this.step,
        answers: answers ?? this.answers,
        baselines: baselines ?? this.baselines,
        saving: saving ?? this.saving,
        saved: saved ?? this.saved,
        milking: milking,
      );

  @override
  List<Object?> get props => [date, loading, existing, step, answers, baselines, saving, saved, milking];
}

/// Registro de hoy como asistente por preguntas: una pregunta por pantalla, todas opcionales ("No
/// sé"). Los números se estiman con la línea base de la vaca si no hay medidas exactas.
class DailyRecordCubit extends Cubit<DailyRecordState> {
  DailyRecordCubit(this._repository, {required this.cowId, DateTime? date, bool milking = true, Uuid? uuid})
      : _uuid = uuid ?? const Uuid(),
        super(DailyRecordState(date: dateOnly(date ?? DateTime.now()), milking: milking));

  final RecordRepository _repository;
  final String cowId;
  final Uuid _uuid;

  /// Carga la línea base y el registro del día. Con [date], cambia de día y empieza de nuevo.
  Future<void> load([DateTime? date]) async {
    final day = dateOnly(date ?? state.date);
    if (day != state.date) {
      emit(DailyRecordState(date: day, milking: state.milking));
    }
    final from = day.subtract(const Duration(days: RecordEquivalences.baselineDays));
    final records = await _repository.recordsBetween(cowId, from, day);
    final existing = records.where((r) => dateOnly(r.recordDate) == day).firstOrNull;
    emit(state.copyWith(
      loading: false,
      existing: () => existing,
      baselines: RecordBaselines.from(records, day),
    ));
  }

  void answerFeed(FeedAnswer value) => _answer(state.answers.copyWith(feed: () => value));

  void answerMilk(MilkAnswer value) => _answer(state.answers.copyWith(milk: () => value));

  void answerBody(BodyAnswer value) => _answer(state.answers.copyWith(body: () => value));

  void answerUdder(UdderAnswer value) => _answer(state.answers.copyWith(udder: () => value));

  /// Guarda la respuesta y pasa sola a la siguiente pregunta.
  void _answer(RecordAnswers answers) {
    final steps = state.steps;
    final index = steps.indexOf(state.step);
    emit(state.copyWith(answers: answers, step: index + 1 < steps.length ? steps[index + 1] : RecordStep.done));
  }

  /// Vuelve a la pregunta anterior (la respuesta se conserva).
  void back() {
    final steps = state.steps;
    final index = state.step == RecordStep.done ? steps.length : steps.indexOf(state.step);
    if (index > 0) emit(state.copyWith(step: steps[index - 1]));
  }

  void restart() => emit(state.copyWith(step: RecordStep.feed, answers: const RecordAnswers()));

  /// Medidas exactas opcionales del bloque "Tengo termómetro o litros exactos".
  void setMeasurements({double? temperatureC, double? milkL, double? feedKg}) =>
      emit(state.copyWith(
        answers: state.answers.copyWith(
          measuredTemperatureC: () => temperatureC,
          measuredMilkL: () => milkL,
          measuredFeedKg: () => feedKg,
        ),
      ));

  Future<void> save({String? notes}) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true));
    final estimate = state.estimate;
    await _repository.saveRecord(DailyRecord(
      id: state.existing?.id ?? _uuid.v4(),
      cowId: cowId,
      recordDate: state.date,
      temperatureC: estimate.temperature?.value,
      milkL: estimate.milk?.value,
      feedKg: estimate.feed?.value,
      temperatureSource: estimate.temperature?.source,
      milkSource: estimate.milk?.source,
      feedSource: estimate.feed?.source,
      symptoms: state.answers.toSymptoms(),
      notes: notes == null || notes.trim().isEmpty ? null : notes.trim(),
      updatedAt: DateTime.now(),
    ));
    emit(state.copyWith(saving: false, saved: true));
  }
}
