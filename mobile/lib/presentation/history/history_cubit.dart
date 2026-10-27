import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities.dart';
import '../../domain/repositories.dart';

class HistoryState extends Equatable {
  const HistoryState({this.loading = true, this.days = 30, this.records = const [], this.inferences = const []});

  final bool loading;
  final int days;
  final List<DailyRecord> records;
  final List<Inference> inferences;

  @override
  List<Object?> get props => [loading, days, records, inferences];
}

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({
    required this.cowId,
    required this._records,
    required this._inferences,
    DateTime Function()? clock,
  })  : _now = clock ?? DateTime.now,
        super(const HistoryState());

  final String cowId;
  final RecordRepository _records;
  final InferenceRepository _inferences;
  final DateTime Function() _now;

  Future<void> load({int? days}) async {
    final span = days ?? state.days;
    emit(HistoryState(days: span, records: state.records, inferences: state.inferences));
    final to = dateOnly(_now());
    final from = to.subtract(Duration(days: span - 1));
    final records = await _records.recordsBetween(cowId, from, to);
    final inferences = await _inferences.inferencesBetween(cowId, from, to);
    emit(HistoryState(loading: false, days: span, records: records, inferences: inferences));
  }
}
