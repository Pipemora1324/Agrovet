import 'package:equatable/equatable.dart';

import 'entities.dart';

// Equivalencias del registro por preguntas: cómo se convierte cada respuesta en un número.
//
// **Pendiente de validar con un veterinario.** Los factores son una primera aproximación para que
// el ganadero sin termómetro ni registro de leche pueda usar el semáforo. Están documentados en
// docs/symptom_score.md; si se cambian, hay que subir [RecordEquivalences.version] y actualizar
// ese documento.

/// 1. ¿Cómo comió hoy?
enum FeedAnswer {
  normal('Normal'),
  less('Menos de lo normal'),
  almostNothing('Casi nada'),
  unknown('No sé');

  const FeedAnswer(this.label);
  final String label;
}

/// 2. ¿Cuánta leche dio?
enum MilkAnswer {
  same('Igual'),
  littleLess('Un poco menos'),
  muchLess('Mucho menos'),
  unknown('No sé');

  const MilkAnswer(this.label);
  final String label;
}

/// 3. Al tocarla, ¿cómo siente el cuerpo?
enum BodyAnswer {
  normal('Normal'),
  warm('Tibia'),
  hot('Caliente'),
  unknown('No sé');

  const BodyAnswer(this.label);
  final String label;
}

/// 4. ¿Cómo ves la ubre y la leche?
enum UdderAnswer {
  normal('Todo normal'),
  inflamed('Ubre caliente, dura o hinchada'),
  abnormalMilk('Leche con grumos o sangre'),
  unknown('No sé');

  const UdderAnswer(this.label);
  final String label;
}

class RecordEquivalences {
  RecordEquivalences._();

  static const version = 'equivalencias-provisional-1';
  static const notice = 'Equivalencias pendientes de validar con un veterinario.';

  /// Alimento = línea base × factor. "No sé" = línea base (neutro).
  static const feedFactor = {
    FeedAnswer.normal: 1.0,
    FeedAnswer.less: 0.85,
    FeedAnswer.almostNothing: 0.5,
    FeedAnswer.unknown: 1.0,
  };

  /// Leche = línea base × factor.
  static const milkFactor = {
    MilkAnswer.same: 1.0,
    MilkAnswer.littleLess: 0.9,
    MilkAnswer.muchLess: 0.7,
    MilkAnswer.unknown: 1.0,
  };

  /// Temperatura = línea base + grados.
  static const temperatureOffsetC = {
    BodyAnswer.normal: 0.0,
    BodyAnswer.warm: 0.5,
    BodyAnswer.hot: 1.5,
    BodyAnswer.unknown: 0.0,
  };

  /// Valores de referencia cuando la vaca no tiene ninguna medición exacta: las medias de una vaca
  /// sana del generador del dataset (ml/src/generate_dataset.py).
  static const referenceTemperatureC = 38.6;
  static const referenceMilkL = 13.0;
  static const referenceFeedKg = 11.0;

  /// La línea base es el promedio de las mediciones exactas de estos días anteriores.
  static const baselineDays = 30;

  /// Con menos mediciones que esto se usa la última medición exacta.
  static const minBaselineValues = 3;
}

/// De dónde salió la línea base de un valor.
enum BaselineKind {
  average('promedio de sus registros'),
  lastMeasurement('su última medición exacta'),
  reference('valores de referencia');

  const BaselineKind(this.label);
  final String label;
}

class Baseline extends Equatable {
  const Baseline(this.value, this.kind, {this.samples = 0});

  final double value;
  final BaselineKind kind;
  final int samples;

  @override
  List<Object?> get props => [value, kind, samples];
}

/// Línea base de la vaca para temperatura, leche y alimento.
class RecordBaselines extends Equatable {
  const RecordBaselines({required this.temperature, required this.milk, required this.feed});

  final Baseline temperature;
  final Baseline milk;
  final Baseline feed;

  /// Algún valor no tiene historial suficiente (hay que decirlo en pantalla).
  @override
  List<Object?> get props => [temperature, milk, feed];

  bool get usesFallback => [temperature, milk, feed].any((b) => b.kind != BaselineKind.average);

  /// Calcula la línea base con los registros anteriores al día [day]. Solo cuentan los valores
  /// medidos (o de versiones anteriores, que se escribían a mano): promediar estimaciones las
  /// alejaría cada día más de la realidad.
  static RecordBaselines from(List<DailyRecord> records, DateTime day) {
    final before = records.where((r) => dateOnly(r.recordDate).isBefore(dateOnly(day))).toList()
      ..sort((a, b) => a.recordDate.compareTo(b.recordDate));
    Baseline pick(double? Function(DailyRecord) value, ValueSource? Function(DailyRecord) source, double reference) {
      final measured = [
        for (final r in before)
          if (value(r) != null && source(r) != ValueSource.estimated) value(r)!,
      ];
      if (measured.length >= RecordEquivalences.minBaselineValues) {
        return Baseline(measured.reduce((a, b) => a + b) / measured.length, BaselineKind.average,
            samples: measured.length);
      }
      if (measured.isNotEmpty) return Baseline(measured.last, BaselineKind.lastMeasurement, samples: 1);
      return Baseline(reference, BaselineKind.reference);
    }

    return RecordBaselines(
      temperature: pick((r) => r.temperatureC, (r) => r.temperatureSource, RecordEquivalences.referenceTemperatureC),
      milk: pick((r) => r.milkL, (r) => r.milkSource, RecordEquivalences.referenceMilkL),
      feed: pick((r) => r.feedKg, (r) => r.feedSource, RecordEquivalences.referenceFeedKg),
    );
  }
}

/// Respuestas del asistente por preguntas y las medidas exactas opcionales.
class RecordAnswers extends Equatable {
  const RecordAnswers({
    this.feed,
    this.milk,
    this.body,
    this.udder,
    this.measuredTemperatureC,
    this.measuredMilkL,
    this.measuredFeedKg,
  });

  final FeedAnswer? feed;
  final MilkAnswer? milk;
  final BodyAnswer? body;
  final UdderAnswer? udder;
  final double? measuredTemperatureC;
  final double? measuredMilkL;
  final double? measuredFeedKg;

  @override
  List<Object?> get props =>
      [feed, milk, body, udder, measuredTemperatureC, measuredMilkL, measuredFeedKg];

  bool get hasMeasurements => measuredTemperatureC != null || measuredMilkL != null || measuredFeedKg != null;

  RecordAnswers copyWith({
    FeedAnswer? Function()? feed,
    MilkAnswer? Function()? milk,
    BodyAnswer? Function()? body,
    UdderAnswer? Function()? udder,
    double? Function()? measuredTemperatureC,
    double? Function()? measuredMilkL,
    double? Function()? measuredFeedKg,
  }) =>
      RecordAnswers(
        feed: feed == null ? this.feed : feed(),
        milk: milk == null ? this.milk : milk(),
        body: body == null ? this.body : body(),
        udder: udder == null ? this.udder : udder(),
        measuredTemperatureC: measuredTemperatureC == null ? this.measuredTemperatureC : measuredTemperatureC(),
        measuredMilkL: measuredMilkL == null ? this.measuredMilkL : measuredMilkL(),
        measuredFeedKg: measuredFeedKg == null ? this.measuredFeedKg : measuredFeedKg(),
      );

  /// Signos que usa el puntaje por síntomas (docs/symptom_score.md). "No sé" = sin respuesta.
  Symptoms toSymptoms() => Symptoms(
        ateNormally: switch (feed) {
          FeedAnswer.normal => true,
          FeedAnswer.less || FeedAnswer.almostNothing => false,
          _ => null,
        },
        milkDrop: switch (milk) {
          MilkAnswer.same => false,
          MilkAnswer.littleLess || MilkAnswer.muchLess => true,
          _ => null,
        },
        // "Caliente, dura o hinchada" cuenta una sola vez, como inflamación de la ubre (+2)
        udderSwelling: udder == UdderAnswer.inflamed,
        abnormalMilk: udder == UdderAnswer.abnormalMilk,
      );
}

/// Un valor del día con su origen.
class EstimatedValue {
  const EstimatedValue(this.value, this.source);

  final double value;
  final ValueSource source;
}

class RecordEstimate {
  const RecordEstimate({this.temperature, this.milk, this.feed});

  final EstimatedValue? temperature;
  final EstimatedValue? milk;
  final EstimatedValue? feed;
}

class RecordEstimator {
  RecordEstimator._();

  /// Usa la medida exacta si la hay; si no, la estima con la respuesta y la línea base. Sin
  /// respuesta ni medida, el valor queda vacío. Una vaca que no está en ordeño no tiene leche.
  static RecordEstimate estimate(RecordAnswers answers, RecordBaselines baselines, {bool milking = true}) {
    EstimatedValue? value(double? measured, double? factorOrOffset, double Function(double) apply) {
      if (measured != null) return EstimatedValue(measured, ValueSource.measured);
      if (factorOrOffset == null) return null;
      return EstimatedValue(_round(apply(factorOrOffset)), ValueSource.estimated);
    }

    return RecordEstimate(
      temperature: value(
        answers.measuredTemperatureC,
        answers.body == null ? null : RecordEquivalences.temperatureOffsetC[answers.body],
        (offset) => baselines.temperature.value + offset,
      ),
      milk: milking
          ? value(
              answers.measuredMilkL,
              answers.milk == null ? null : RecordEquivalences.milkFactor[answers.milk],
              (factor) => baselines.milk.value * factor,
            )
          : null,
      feed: value(
        answers.measuredFeedKg,
        answers.feed == null ? null : RecordEquivalences.feedFactor[answers.feed],
        (factor) => baselines.feed.value * factor,
      ),
    );
  }

  static double _round(double value) => (value * 10).round() / 10;
}
