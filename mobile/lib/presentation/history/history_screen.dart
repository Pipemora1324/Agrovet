import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../../domain/symptom_score.dart';
import '../photos/photo_gallery.dart';
import '../records/daily_record_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/fade_in.dart';
import '../widgets/traffic_light.dart';
import 'history_cubit.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => HistoryCubit(
      cowId: cow.id,
      records: context.read<RecordRepository>(),
      inferences: context.read<InferenceRepository>(),
    )..load(),
    child: _HistoryView(cow: cow),
  );
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Historial · ${cow.name ?? cow.tag}',
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
          final to = dateOnly(DateTime.now());
          final from = to.subtract(Duration(days: state.days - 1));
          final charts = [
            _MetricChart(
              title: 'Temperatura (°C)',
              icon: Icons.thermostat,
              color: AppColors.chartTemperature,
              from: from,
              days: state.days,
              values: {
                for (final r in state.records) r.recordDate: r.temperatureC,
              },
              estimated: {
                for (final r in state.records)
                  if (r.temperatureEstimated) r.recordDate,
              },
            ),
            _MetricChart(
              title: 'Leche (L)',
              icon: Icons.water_drop,
              color: AppColors.chartMilk,
              from: from,
              days: state.days,
              values: {for (final r in state.records) r.recordDate: r.milkL},
              estimated: {
                for (final r in state.records)
                  if (r.milkEstimated) r.recordDate,
              },
            ),
            _MetricChart(
              title: 'Alimento (kg)',
              icon: Icons.grass,
              color: AppColors.chartFeed,
              from: from,
              days: state.days,
              values: {for (final r in state.records) r.recordDate: r.feedKg},
              estimated: {
                for (final r in state.records)
                  if (r.feedEstimated) r.recordDate,
              },
            ),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CenteredContent(
                maxWidth: 1100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 14, label: Text('14 días')),
                        ButtonSegment(value: 30, label: Text('30 días')),
                        ButtonSegment(value: 60, label: Text('60 días')),
                      ],
                      selected: {state.days},
                      onSelectionChanged: (s) =>
                          context.read<HistoryCubit>().load(days: s.first),
                    ),
                    const SizedBox(height: 16),
                    if (state.loading && state.records.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.records.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No hay registros en este periodo.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns =
                              constraints.maxWidth >= Responsive.tabletWidth
                              ? 2
                              : 1;
                          final width =
                              (constraints.maxWidth - 12 * (columns - 1)) /
                              columns;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (var i = 0; i < charts.length; i++)
                                SizedBox(
                                  width: width,
                                  child: FadeIn(index: i, child: charts[i]),
                                ),
                            ],
                          );
                        },
                      ),
                    if (state.records.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Punto relleno: valor medido. Punto hueco: valor estimado por la app.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Registros',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final record in state.records.reversed)
                        _RecordTile(record: record),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Fotos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<CowPhoto>>(
                      stream: context.read<PhotoRepository>().watchPhotos(
                        cow.id,
                      ),
                      builder: (context, snapshot) {
                        final photos = (snapshot.data ?? const <CowPhoto>[])
                            .where(
                              (p) =>
                                  !p.takenOn.isBefore(from) &&
                                  !p.takenOn.isAfter(to),
                            )
                            .toList();
                        return photos.isEmpty
                            ? Text(
                                'Sin fotos en este periodo.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              )
                            : PhotoGallery(photos: photos);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Evaluaciones del semáforo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (state.inferences.isEmpty)
                      Text(
                        'Sin evaluaciones en este periodo.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      )
                    else
                      for (final inference in state.inferences.reversed)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              inference.riskLevel.icon,
                              color: inference.riskLevel.color,
                              size: 32,
                            ),
                            title: Text(formatDay(inference.windowEndDate)),
                            subtitle: Text(_inferenceSummary(inference)),
                            trailing: RiskChip(level: inference.riskLevel),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricChart extends StatelessWidget {
  const _MetricChart({
    required this.title,
    required this.icon,
    required this.color,
    required this.from,
    required this.days,
    required this.values,
    this.estimated = const {},
  });

  final String title;
  final IconData icon;
  final Color color;
  final DateTime from;
  final int days;
  final Map<DateTime, double?> values;

  /// Días con el valor estimado por la app (se dibujan con el punto hueco).
  final Set<DateTime> estimated;

  @override
  Widget build(BuildContext context) {
    // Un día sin dato corta la línea en lugar de inventar un valor
    final spots = [
      for (var i = 0; i < days; i++)
        () {
          final value = values[DateTime(from.year, from.month, from.day + i)];
          return value == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), value);
        }(),
    ];
    final present = spots
        .where((s) => s != FlSpot.nullSpot)
        .map((s) => s.y)
        .toList();
    final minY = present.isEmpty ? 0.0 : present.reduce(math.min);
    final maxY = present.isEmpty ? 1.0 : present.reduce(math.max);
    final pad = math.max((maxY - minY) * 0.2, 0.5);
    final labelEvery = days <= 14 ? 3 : (days <= 30 ? 7 : 14);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              padding: const EdgeInsets.only(right: 12),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (days - 1).toDouble(),
                  minY: minY - pad,
                  maxY: maxY + pad,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: color,
                      barWidth: 3.5,
                      dotData: FlDotData(
                        show: days <= 30,
                        getDotPainter: (spot, _, _, _) =>
                            estimated.contains(
                              DateTime(
                                from.year,
                                from.month,
                                from.day + spot.x.toInt(),
                              ),
                            )
                            ? FlDotCirclePainter(
                                radius: 4.5,
                                color: AppColors.surface,
                                strokeColor: color,
                                strokeWidth: 2.5,
                              )
                            : FlDotCirclePainter(
                                radius: 4,
                                color: color,
                                strokeWidth: 0,
                              ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.10),
                      ),
                    ),
                  ],
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        // Los extremos del eje no van rotulados para que no se encimen con las líneas guía
                        getTitlesWidget: (value, meta) =>
                            value == meta.min || value == meta.max
                            ? const SizedBox.shrink()
                            : SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  formatNumber(value),
                                  style: Theme.of(context).textTheme.axis,
                                ),
                              ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          final lastIndex = days - 1;
                          // El último día se rotula solo si no queda pegado al rótulo anterior
                          final showLast =
                              index == lastIndex &&
                              lastIndex % labelEvery >= labelEvery / 2;
                          if (index % labelEvery != 0 && !showLast) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime(
                            from.year,
                            from.month,
                            from.day + index,
                          );
                          return SideTitleWidget(
                            meta: meta,
                            // El rótulo del borde no se corta con letra grande
                            fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                            child: Text(
                              formatShortDay(date),
                              style: Theme.of(context).textTheme.axis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                duration: Responsive.motion(
                  context,
                  const Duration(milliseconds: 400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un registro del historial: valores del día con su origen (medido o estimado) y los signos.
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final DailyRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      (Icons.thermostat, record.temperatureC, '°C', record.temperatureSource),
      (Icons.water_drop, record.milkL, 'L', record.milkSource),
      (Icons.grass, record.feedKg, 'kg', record.feedSource),
    ].where((v) => v.$2 != null);
    final signs = SymptomScore.assess(record).reasons;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDay(record.recordDate),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            if (values.isEmpty)
              Text(
                'Sin temperatura, leche ni alimento.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final (icon, value, unit, source) in values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${formatNumber(value)} $unit',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(width: 6),
                        // Los registros anteriores al asistente se escribían a mano: cuentan como medidos
                        SourceChip(measured: source != ValueSource.estimated),
                      ],
                    ),
                ],
              ),
            if (signs.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                signs.map((s) => s.label).join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Resume el resultado con los signos que se tuvieron en cuenta.
String _inferenceSummary(Inference inference) {
  final parts = [
    if (inference.symptomScore != null)
      'Síntomas ${inference.symptomScore} pts',
    if (inference.probability != null) 'Registros recientes',
  ];
  return parts.isEmpty ? 'Sin señales destacadas' : parts.join(' · ');
}
