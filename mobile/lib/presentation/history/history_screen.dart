import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
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
              color: const Color(0xFFC62828),
              from: from,
              days: state.days,
              values: {for (final r in state.records) r.recordDate: r.temperatureC},
            ),
            _MetricChart(
              title: 'Leche (L)',
              icon: Icons.water_drop,
              color: const Color(0xFF1565C0),
              from: from,
              days: state.days,
              values: {for (final r in state.records) r.recordDate: r.milkL},
            ),
            _MetricChart(
              title: 'Alimento (kg)',
              icon: Icons.grass,
              color: const Color(0xFF6D4C1F),
              from: from,
              days: state.days,
              values: {for (final r in state.records) r.recordDate: r.feedKg},
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
                      style: SegmentedButton.styleFrom(
                        minimumSize: const Size(64, 56),
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      segments: const [
                        ButtonSegment(value: 14, label: Text('14 días')),
                        ButtonSegment(value: 30, label: Text('30 días')),
                        ButtonSegment(value: 60, label: Text('60 días')),
                      ],
                      selected: {state.days},
                      onSelectionChanged: (s) => context.read<HistoryCubit>().load(days: s.first),
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
                        child: Text('No hay registros en este periodo.',
                            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= Responsive.tabletWidth ? 2 : 1;
                          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (var i = 0; i < charts.length; i++)
                                SizedBox(width: width, child: FadeIn(index: i, child: charts[i])),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    Text('Evaluaciones del semáforo', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (state.inferences.isEmpty)
                      Text('Sin evaluaciones en este periodo.', style: Theme.of(context).textTheme.bodyLarge)
                    else
                      for (final inference in state.inferences.reversed)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(inference.riskLevel.icon, color: inference.riskLevel.color, size: 32),
                            title: Text(formatDay(inference.windowEndDate),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            subtitle: Text('Probabilidad ${formatPercent(inference.probability)}',
                                style: const TextStyle(fontSize: 16)),
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
  });

  final String title;
  final IconData icon;
  final Color color;
  final DateTime from;
  final int days;
  final Map<DateTime, double?> values;

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
    final present = spots.where((s) => s != FlSpot.nullSpot).map((s) => s.y).toList();
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
            SizedBox(
              height: 180,
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
                      dotData: FlDotData(show: days <= 30),
                      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.10)),
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
                        getTitlesWidget: (value, meta) => value == meta.min || value == meta.max
                            ? const SizedBox.shrink()
                            : SideTitleWidget(
                                meta: meta,
                                child: Text(formatNumber(value),
                                    style: const TextStyle(fontSize: 13, color: AppTheme.ink)),
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
                          final showLast = index == lastIndex && lastIndex % labelEvery >= labelEvery / 2;
                          if (index % labelEvery != 0 && !showLast) return const SizedBox.shrink();
                          final date = DateTime(from.year, from.month, from.day + index);
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(formatShortDay(date), style: const TextStyle(fontSize: 13, color: AppTheme.ink)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                duration: Responsive.motion(context, const Duration(milliseconds: 400)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
