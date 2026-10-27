import 'dart:math';

import '../../domain/entities.dart';
import '../local/local_repository.dart';

/// Datos de demostración para ver la app con contenido en el emulador.
///
/// Solo se usan en compilaciones debug, en una base aparte ("demo") que nunca se sincroniza.
/// Las vacas llevan el prefijo DEMO y la app muestra el rótulo "Datos de demostración".
/// Los valores se inventan aquí; el semáforo sí lo calcula el modelo real.
class DemoSeed {
  DemoSeed(this.repository, {DateTime? today, int seed = 7})
      : _today = dateOnly(today ?? DateTime.now()),
        _random = Random(seed);

  final LocalRepository repository;
  final DateTime _today;
  final Random _random;

  static const days = 30;

  Future<void> seedIfEmpty() async {
    final cows = await repository.watchCows().first;
    if (cows.isNotEmpty) return;

    await _cow('DEMO-01', 'Lucero', 'Holstein', baseTemp: 38.6, baseMilk: 14, baseFeed: 11);
    await _cow('DEMO-02', 'Canela', 'Normando', baseTemp: 38.5, baseMilk: 12, baseFeed: 10,
        subclinicalDays: 6, symptomsToday: const Symptoms(abnormalMilk: true));
    await _cow('DEMO-03', 'Mariposa', 'Jersey', baseTemp: 38.7, baseMilk: 10, baseFeed: 9, estrusDaysAgo: 1);
    await _cow('DEMO-04', 'Estrella', 'Holstein', baseTemp: 38.6, baseMilk: 16, baseFeed: 12,
        withTypos: true);
    await _cow('DEMO-05', 'Paloma', 'Criolla', baseTemp: 38.4, baseMilk: 8, baseFeed: 8, recordedDays: 6);
    await _cow('DEMO-06', 'Luna', 'Normando', baseTemp: 38.5, baseMilk: 0, baseFeed: 10,
        status: ProductionStatus.dry, recordedDays: 0);
  }

  Future<void> _cow(
    String tag,
    String name,
    String breed, {
    required double baseTemp,
    required double baseMilk,
    required double baseFeed,
    ProductionStatus status = ProductionStatus.lactating,
    int recordedDays = days,
    int subclinicalDays = 0,
    int? estrusDaysAgo,
    bool withTypos = false,
    Symptoms symptomsToday = const Symptoms(),
  }) async {
    final cowId = 'demo-${tag.toLowerCase()}';
    await repository.saveCow(Cow(
      id: cowId,
      tag: tag,
      name: name,
      breed: breed,
      birthDate: DateTime(_today.year - 4 - _random.nextInt(4), 1 + _random.nextInt(12), 1 + _random.nextInt(27)),
      calvings: 1 + _random.nextInt(4),
      productionStatus: status,
      updatedAt: _today,
      isDemo: true,
    ));

    for (var ago = recordedDays - 1; ago >= 0; ago--) {
      final date = _today.subtract(Duration(days: ago));
      var temp = baseTemp + _noise(0.12);
      var milk = baseMilk * (1 + _noise(0.04));
      var feed = baseFeed * (1 + _noise(0.05));

      if (ago < subclinicalDays) {
        // Fase subclínica: sube la temperatura y bajan leche y alimento poco a poco
        final progress = (subclinicalDays - ago) / subclinicalDays;
        temp += 0.9 * progress;
        milk *= 1 - 0.22 * progress;
        feed *= 1 - 0.15 * progress;
      }
      if (estrusDaysAgo != null && ago == estrusDaysAgo) {
        temp += 0.45;
        milk *= 0.9;
        feed *= 0.9;
      }
      double? tempValue = double.parse(temp.toStringAsFixed(1));
      double? milkValue = double.parse(milk.toStringAsFixed(1));
      if (withTypos && ago == 3) tempValue = 3.86; // error de digitación: el modelo lo trata como faltante
      if (withTypos && ago == 8) milkValue = null; // día sin dato de leche

      await repository.saveRecord(DailyRecord(
        id: '$cowId-$ago',
        cowId: cowId,
        recordDate: date,
        temperatureC: tempValue,
        milkL: status == ProductionStatus.dry ? null : milkValue,
        feedKg: double.parse(feed.toStringAsFixed(1)),
        symptoms: ago == 0 ? symptomsToday : const Symptoms(),
        notes: 'Dato de demostración',
        updatedAt: date,
      ));
    }
  }

  double _noise(double scale) => (_random.nextDouble() * 2 - 1) * scale;
}
