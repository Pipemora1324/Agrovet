import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities.dart';
import '../../domain/repositories.dart';

class CowsState extends Equatable {
  const CowsState({this.loading = true, this.cows = const []});

  final bool loading;
  final List<CowSummary> cows;

  @override
  List<Object?> get props => [loading, cows];
}

class CowsCubit extends Cubit<CowsState> {
  CowsCubit(this._repository) : super(const CowsState()) {
    _subscription = _repository.watchCows().listen((cows) => emit(CowsState(loading: false, cows: cows)));
  }

  final CowRepository _repository;
  late final StreamSubscription<List<CowSummary>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

/// Resultado de guardar una vaca: null si salió bien, o el mensaje de error.
class CowEditor {
  CowEditor(this._repository, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final CowRepository _repository;
  final Uuid _uuid;

  Future<String?> save({
    Cow? existing,
    required String tag,
    String? name,
    String? breed,
    DateTime? birthDate,
    int? calvings,
    required ProductionStatus status,
  }) async {
    final cleanTag = tag.trim();
    if (await _repository.isTagInUse(cleanTag, exceptId: existing?.id)) {
      return 'Ya tiene otra vaca con el identificador $cleanTag';
    }
    await _repository.saveCow(Cow(
      // El id se genera en el celular para poder crear vacas sin conexión
      id: existing?.id ?? _uuid.v4(),
      tag: cleanTag,
      name: _blankToNull(name),
      breed: _blankToNull(breed),
      birthDate: birthDate,
      calvings: calvings,
      productionStatus: status,
      updatedAt: DateTime.now(),
      isDemo: existing?.isDemo ?? false,
    ));
    return null;
  }

  Future<void> delete(Cow cow) => _repository.deleteCow(cow.id);

  static String? _blankToNull(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
