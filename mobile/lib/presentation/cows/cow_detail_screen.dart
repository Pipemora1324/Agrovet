import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../../domain/risk_advice.dart';
import '../../domain/symptom_score.dart';
import '../assistant/assistant_screen.dart';
import '../history/history_screen.dart';
import '../photos/cow_photos_screen.dart';
import '../records/daily_record_screen.dart';
import '../risk/risk_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/big_button.dart';
import '../widgets/fade_in.dart';
import '../widgets/motion.dart';
import '../widgets/traffic_light.dart';
import 'cow_form_screen.dart';
import 'cows_cubit.dart';
import 'cows_screen.dart';

/// Días que se muestran en la gráfica de la ficha (los mismos que mira el modelo).
const _trendDays = 14;

class CowDetailScreen extends StatefulWidget {
  const CowDetailScreen({super.key, required this.cowId});

  final String cowId;

  @override
  State<CowDetailScreen> createState() => _CowDetailScreenState();
}

class _CowDetailScreenState extends State<CowDetailScreen> {
  late Future<List<DailyRecord>> _records = _loadRecords();

  DateTime get _today => dateOnly(DateTime.now());

  Future<List<DailyRecord>> _loadRecords() =>
      context.read<RecordRepository>().recordsBetween(
        widget.cowId,
        _today.subtract(const Duration(days: _trendDays - 1)),
        _today,
      );

  /// Abre otra pantalla y, al volver, recarga los registros (pudo haber uno nuevo).
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    final records = _loadRecords();
    setState(() {
      _records = records;
    });
  }

  Future<void> _confirmDelete(Cow cow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Dar de baja a ${cow.name ?? cow.tag}?'),
        content: const Text(
          'Dejará de aparecer en la lista. Sus registros se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: AppButtonStyles.dangerFilled(context),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await CowEditor(context.read<CowRepository>()).delete(cow);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cows = context.read<CowRepository>();
    final inferences = context.read<InferenceRepository>();
    return StreamBuilder<Cow?>(
      stream: cows.watchCow(widget.cowId),
      builder: (context, snapshot) {
        final cow = snapshot.data;
        if (cow == null) {
          return const AppScaffold(
            title: 'Vaca',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return AppScaffold(
          title: cow.name ?? cow.tag,
          actions: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: () => _open(CowFormScreen(cow: cow)),
            ),
            IconButton(
              tooltip: 'Dar de baja',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(cow),
            ),
          ],
          body: StreamBuilder<Inference?>(
            stream: inferences.watchLatest(widget.cowId),
            builder: (context, latest) => FutureBuilder<List<DailyRecord>>(
              future: _records,
              builder: (context, records) {
                final list = records.data ?? const <DailyRecord>[];
                final header = _Header(cow: cow, latest: latest.data);
                final risk = _RiskPanel(latest: latest.data, records: list);
                final alerts = _PendingAlerts(cowId: widget.cowId);
                final trend = _TrendCard(records: list, today: _today);
                final production = _ProductionCard(
                  records: list,
                  today: _today,
                );
                final actions = _Actions(cow: cow, open: _open);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Responsive.isTablet(context)
                      // Tableta: semáforo y razones a la izquierda, gráficas a la derecha
                      ? CenteredContent(
                          maxWidth: 1100,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    FadeIn(child: header),
                                    const SizedBox(height: 16),
                                    FadeIn(index: 1, child: risk),
                                    const SizedBox(height: 16),
                                    alerts,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    FadeIn(index: 2, child: trend),
                                    const SizedBox(height: 16),
                                    FadeIn(index: 3, child: production),
                                    const SizedBox(height: 16),
                                    FadeIn(index: 4, child: actions),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : CenteredContent(
                          child: Column(
                            children: [
                              FadeIn(child: header),
                              const SizedBox(height: 16),
                              FadeIn(index: 1, child: risk),
                              const SizedBox(height: 16),
                              alerts,
                              FadeIn(index: 2, child: actions),
                              const SizedBox(height: 16),
                              FadeIn(index: 3, child: trend),
                              const SizedBox(height: 16),
                              FadeIn(index: 4, child: production),
                            ],
                          ),
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Identificación de la vaca y sus datos básicos.
class _Header extends StatelessWidget {
  const _Header({required this.cow, this.latest});

  final Cow cow;
  final Inference? latest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = cow.birthDate == null ? null : _ageText(cow.birthDate!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'cow-avatar-${cow.id}',
                  child: CowAvatar(level: latest?.riskLevel, size: 64),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cow.name ?? cow.tag,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        '${cow.tag} · ${cow.productionStatus.label}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Fact(icon: Icons.category, text: cow.breed ?? 'Raza sin dato'),
                _Fact(icon: Icons.cake, text: age ?? 'Edad sin dato'),
                _Fact(
                  icon: Icons.child_care,
                  text: cow.calvings == null
                      ? 'Partos sin dato'
                      : 'Partos: ${cow.calvings}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _ageText(DateTime birth) {
    final now = DateTime.now();
    var months = (now.year - birth.year) * 12 + now.month - birth.month;
    if (now.day < birth.day) months--;
    if (months < 12) return '$months meses';
    final years = months ~/ 12;
    return years == 1 ? '1 año' : '$years años';
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: AppRadius.field,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// Último semáforo y las señales que se tuvieron en cuenta.
class _RiskPanel extends StatelessWidget {
  const _RiskPanel({required this.latest, required this.records});

  final Inference? latest;
  final List<DailyRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = latest;
    if (value == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const RiskChip(level: null),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Todavía no se ha evaluado el riesgo. Haga el registro de hoy y toque "Evaluar riesgo".',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final level = value.riskLevel;
    final record = records
        .where((r) => dateOnly(r.recordDate) == dateOnly(value.windowEndDate))
        .firstOrNull;
    final reasons = _reasons(
      value,
      record == null ? null : SymptomScore.assess(record),
    );
    final light = TrafficLight(level: level, size: 84);
    return Card(
      color: level.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: level.color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                light,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.label,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: level.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Evaluado: ${formatDay(value.windowEndDate)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: level.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Señales registradas',
              style: theme.textTheme.titleMedium?.copyWith(
                color: level.textColor,
              ),
            ),
            const SizedBox(height: 8),
            for (final (icon, text) in reasons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 22, color: level.textColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: level.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              RiskAdvice.disclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: level.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Razones en lenguaje sencillo, de la más importante a la menos.
  static List<(IconData, String)> _reasons(
    Inference inference,
    SymptomAssessment? symptoms,
  ) {
    final list = <(IconData, String)>[];
    if (inference.probability != null) {
      list.add((
        Icons.insights,
        'Se tuvieron en cuenta la temperatura, la leche y el alimento recientes.',
      ));
    } else {
      list.add((
        Icons.hourglass_empty,
        'Hay pocos registros anteriores; se revisaron los signos de hoy.',
      ));
    }
    if (symptoms != null) {
      if (symptoms.reasons.isEmpty) {
        list.add((
          Icons.check_circle_outline,
          'No se marcó ningún signo en la ubre ni en la leche.',
        ));
      } else {
        for (final reason in symptoms.reasons) {
          list.add((Icons.circle, '${reason.label} (+${reason.points}).'));
        }
      }
    }
    return list;
  }
}

/// Temperatura de los últimos 14 días; la línea se dibuja al aparecer.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.records, required this.today});

  final List<DailyRecord> records;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = today.subtract(const Duration(days: _trendDays - 1));
    final byDay = {
      for (final r in records) dateOnly(r.recordDate): r.temperatureC,
    };
    final spots = [
      for (var i = 0; i < _trendDays; i++)
        () {
          final value = byDay[DateTime(from.year, from.month, from.day + i)];
          return value == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), value);
        }(),
    ];
    final present = spots
        .where((s) => s != FlSpot.nullSpot)
        .map((s) => s.y)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.thermostat, color: AppColors.chartTemperature),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Temperatura, 14 días',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (present.isEmpty)
              Text(
                'Sin temperaturas registradas en estos días.',
                style: theme.textTheme.bodyLarge,
              )
            else
              SizedBox(
                height: 170,
                child: DrawIn(
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: _trendDays - 1,
                      minY: math.min(37.5, present.reduce(math.min) - 0.3),
                      maxY: math.max(40.5, present.reduce(math.max) + 0.3),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          preventCurveOverShooting: true,
                          color: AppColors.chartTemperature,
                          barWidth: 3.5,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.chartTemperature.withValues(
                              alpha: 0.10,
                            ),
                          ),
                        ),
                      ],
                      // Línea de fiebre como referencia
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: SymptomScore.feverC,
                            color: AppColors.riskRed.withValues(alpha: 0.5),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                          ),
                        ],
                      ),
                      gridData: const FlGridData(drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            interval: 1,
                            getTitlesWidget: (value, meta) =>
                                value == meta.min || value == meta.max
                                ? const SizedBox.shrink()
                                : SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      formatNumber(value, decimals: 0),
                                      style: theme.textTheme.axis,
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
                              if (index % 4 != 0 && index != _trendDays - 1) {
                                return const SizedBox.shrink();
                              }
                              if (index == 12) return const SizedBox.shrink();
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  index == _trendDays - 1
                                      ? 'Hoy'
                                      : formatShortDay(
                                          DateTime(
                                            from.year,
                                            from.month,
                                            from.day + index,
                                          ),
                                        ),
                                  style: theme.textTheme.axis,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Línea punteada: fiebre (${formatNumber(SymptomScore.feverC)} °C).',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Leche y alimento de los últimos 14 días, en barras que crecen.
class _ProductionCard extends StatelessWidget {
  const _ProductionCard({required this.records, required this.today});

  final List<DailyRecord> records;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final from = today.subtract(const Duration(days: _trendDays - 1));
    final byDay = {for (final r in records) dateOnly(r.recordDate): r};
    final days = [
      for (var i = 0; i < _trendDays; i++)
        byDay[DateTime(from.year, from.month, from.day + i)],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Series(
              icon: Icons.water_drop,
              title: 'Leche',
              unit: 'L',
              color: AppColors.chartMilk,
              values: [for (final d in days) d?.milkL],
              estimated: {
                for (var i = 0; i < days.length; i++)
                  if (days[i]?.milkEstimated ?? false) i,
              },
            ),
            const Divider(height: 32),
            _Series(
              icon: Icons.grass,
              title: 'Alimento',
              unit: 'kg',
              color: AppColors.chartFeed,
              values: [for (final d in days) d?.feedKg],
              estimated: {
                for (var i = 0; i < days.length; i++)
                  if (days[i]?.feedEstimated ?? false) i,
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Series extends StatelessWidget {
  const _Series({
    required this.icon,
    required this.title,
    required this.unit,
    required this.color,
    required this.values,
    required this.estimated,
  });

  final IconData icon;
  final String title;
  final String unit;
  final Color color;
  final List<double?> values;
  final Set<int> estimated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = values.whereType<double>().toList();
    final average = present.isEmpty
        ? null
        : present.reduce((a, b) => a + b) / present.length;
    final last = values.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title, 14 días',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          present.isEmpty
              ? 'Sin datos en estos días.'
              : 'Hoy: ${last == null ? 'sin dato' : '${formatNumber(last)} $unit'} · '
                    'Promedio: ${formatNumber(average)} $unit',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Semantics(
          label: '$title de los últimos 14 días',
          excludeSemantics: true,
          child: GrowColumns(
            values: values,
            color: color,
            height: 80,
            estimated: estimated,
          ),
        ),
        if (estimated.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Las barras claras son valores estimados.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Alertas amarillas o rojas sin atender. Desaparece cuando no hay ninguna.
class _PendingAlerts extends StatelessWidget {
  const _PendingAlerts({required this.cowId});

  final String cowId;

  Future<void> _markAttended(BuildContext context, CowAlert alert) async {
    await context.read<AlertRepository>().markAlertAttended(alert.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta marcada como atendida.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<CowAlert>>(
      stream: context.read<AlertRepository>().watchPendingAlerts(cowId),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <CowAlert>[];
        if (alerts.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.card,
              side: BorderSide(color: alerts.first.riskLevel.color, width: 3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: alerts.first.riskLevel.color,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alerts.length == 1
                              ? 'Alerta sin atender'
                              : '${alerts.length} alertas sin atender',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  for (final alert in alerts) ...[
                    const Divider(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RiskChip(level: alert.riskLevel),
                        Text(
                          formatDay(alert.createdAt),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BigButton(
                      icon: Icons.check_circle,
                      label: 'Marcar como atendida',
                      outlined: true,
                      onPressed: () => _markAttended(context, alert),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.cow, required this.open});

  final Cow cow;
  final Future<void> Function(Widget screen) open;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BigButton(
        icon: Icons.edit_note,
        label: 'Registro de hoy',
        onPressed: () => open(DailyRecordScreen(cow: cow)),
      ),
      const SizedBox(height: 12),
      BigButton(
        icon: Icons.traffic,
        label: 'Evaluar riesgo',
        onPressed: () => open(RiskScreen(cow: cow)),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: BigButton(
              icon: Icons.photo_camera,
              label: 'Fotos',
              outlined: true,
              onPressed: () => open(CowPhotosScreen(cow: cow)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BigButton(
              icon: Icons.show_chart,
              label: 'Ver historial',
              outlined: true,
              onPressed: () => open(HistoryScreen(cow: cow)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      BigButton(
        icon: Icons.chat,
        label: 'Preguntar al asistente',
        outlined: true,
        onPressed: () => open(AssistantScreen(cow: cow)),
      ),
    ],
  );
}
