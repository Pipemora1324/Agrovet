import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities.dart';
import '../../domain/repositories.dart';

class DailyRecordState extends Equatable {
  const DailyRecordState({
    required this.date,
    this.loading = true,
    this.existing,
    this.symptoms = const Symptoms(),
    this.saving = false,
    this.saved = false,
  });

  final DateTime date;
  final bool loading;

  /// Registro ya guardado para ese día (se edita en lugar de duplicarlo).
  final DailyRecord? existing;
  final Symptoms symptoms;
  final bool saving;
  final bool saved;

  DailyRecordState copyWith({
    DateTime? date,
    bool? loading,
    DailyRecord? existing,
    bool clearExisting = false,
    Symptoms? symptoms,
    bool? saving,
    bool? saved,
  }) =>
      DailyRecordState(
        date: date ?? this.date,
        loading: loading ?? this.loading,
        existing: clearExisting ? null : existing ?? this.existing,
        symptoms: symptoms ?? this.symptoms,
        saving: saving ?? this.saving,
        saved: saved ?? this.saved,
      );

  @override
  List<Object?> get props => [date, loading, existing, symptoms, saving, saved];
}

class DailyRecordCubit extends Cubit<DailyRecordState> {
  DailyRecordCubit(this._repository, {required this.cowId, DateTime? date, Uuid? uuid})
      : _uuid = uuid ?? const Uuid(),
        super(DailyRecordState(date: dateOnly(date ?? DateTime.now())));

  final RecordRepository _repository;
  final String cowId;
  final Uuid _uuid;

  Future<void> load([DateTime? date]) async {
    final day = dateOnly(date ?? state.date);
    emit(state.copyWith(date: day, loading: true, saved: false));
    final existing = await _repository.recordFor(cowId, day);
    emit(state.copyWith(
      loading: false,
      existing: existing,
      clearExisting: existing == null,
      symptoms: existing?.symptoms ?? const Symptoms(),
    ));
  }

  void updateSymptoms(Symptoms symptoms) => emit(state.copyWith(symptoms: symptoms));

  Future<void> save({double? temperatureC, double? milkL, double? feedKg, String? notes}) async {
    emit(state.copyWith(saving: true));
    await _repository.saveRecord(DailyRecord(
      id: state.existing?.id ?? _uuid.v4(),
      cowId: cowId,
      recordDate: state.date,
      temperatureC: temperatureC,
      milkL: milkL,
      feedKg: feedKg,
      symptoms: state.symptoms,
      notes: notes == null || notes.trim().isEmpty ? null : notes.trim(),
      updatedAt: DateTime.now(),
    ));
    emit(state.copyWith(saving: false, saved: true));
  }
}
