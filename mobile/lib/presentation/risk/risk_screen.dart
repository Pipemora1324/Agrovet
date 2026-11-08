import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../../domain/risk_advice.dart';
import '../../domain/risk_evaluator.dart';
import '../../domain/symptom_score.dart';
import '../records/daily_record_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/big_button.dart';
import '../widgets/fade_in.dart';
import '../widgets/traffic_light.dart';
import 'risk_cubit.dart';

class RiskScreen extends StatelessWidget {
  const RiskScreen({super.key, required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => RiskCubit(
          cowId: cow.id,
          records: context.read<RecordRepository>(),
          inferences: context.read<InferenceRepository>(),
          evaluator: context.read<RiskEvaluator>(),
        )..evaluate(),
        child: RiskView(cow: cow),
      );
}

class RiskView extends StatelessWidget {
  const RiskView({super.key, required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Riesgo · ${cow.name ?? cow.tag}',
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<RiskCubit, RiskState>(
              builder: (context, state) => AnimatedSwitcher(
                duration: Responsive.motion(context, const Duration(milliseconds: 350)),
                child: switch (state) {
                  RiskState(evaluating: true) => const _Evaluating(key: ValueKey('evaluating')),
                  RiskState(error: final String error) => _Message(key: const ValueKey('error'), text: error),
                  RiskState(outcome: final NothingToEvaluate data) =>
                    _NothingToEvaluate(key: const ValueKey('nothing'), data: data, cow: cow),
                  RiskState(outcome: final CombinedRisk result) =>
                    _Result(key: const ValueKey('result'), result: result, symptoms: state.todaySymptoms),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ),
          const _Disclaimer(),
        ],
      ),
    );
  }
}

class _Evaluating extends StatelessWidget {
  const _Evaluating({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 6)),
            const SizedBox(height: 20),
            Text('Analizando los últimos 14 días…', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}

/// Sin registro de hoy y sin días suficientes para el modelo.
class _NothingToEvaluate extends StatelessWidget {
  const _NothingToEvaluate({super.key, required this.data, required this.cow});

  final NothingToEvaluate data;
  final Cow cow;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: CenteredContent(
          maxWidth: 560,
          child: FadeIn(
            child: Column(
              children: [
                const Icon(Icons.event_busy, size: 72, color: AppColors.warningText),
                const SizedBox(height: 16),
                Text('Faltan registros', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  'Haga el registro de hoy: con las preguntas y los signos de la ubre ya se puede evaluar. '
                  '${data.modelMissing.message}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                BigButton(
                  icon: Icons.edit_note,
                  label: 'Hacer el registro de hoy',
                  onPressed: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => DailyRecordScreen(cow: cow))),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Result extends StatelessWidget {
  const _Result({super.key, required this.result, required this.symptoms});

  final CombinedRisk result;
  final Symptoms symptoms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = result.level;
    final advice = RiskAdvice.forLevel(level, symptoms: symptoms);
    final light = FadeIn(child: TrafficLight(level: level, size: Responsive.isTablet(context) ? 84 : 68));
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeIn(
          index: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: level.color, borderRadius: AppRadius.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(level.icon, color: level.onColor, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(level.label, style: theme.textTheme.headlineSmall?.copyWith(color: level.onColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  // En verde no hay alerta que atribuir: se dice con qué se evaluó
                  level == RiskLevel.green ? 'Evaluado con: ${result.cause.label}.' : 'Lo indicó: ${result.cause.label}.',
                  style: theme.textTheme.titleSmall?.copyWith(color: level.onColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeIn(index: 2, child: _SymptomsCard(assessment: result.symptoms, decisive: _decides(RiskCause.symptoms))),
        const SizedBox(height: 12),
        FadeIn(
          index: 3,
          child: _ModelCard(result: result.model, missing: result.modelMissing, decisive: _decides(RiskCause.model)),
        ),
        const SizedBox(height: 16),
        FadeIn(
          index: 4,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(advice.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final step in advice.steps) _Bullet(text: step),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Evaluado el ${formatDay(result.evaluatedOn).toLowerCase()}.', style: theme.textTheme.bodyMedium),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Responsive.isTablet(context)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [light, const SizedBox(width: 32), Expanded(child: details)],
            )
          : CenteredContent(
              child: Column(children: [light, const SizedBox(height: 20), details]),
            ),
    );
  }

  bool _decides(RiskCause which) => result.level != RiskLevel.green &&
      (result.cause == which || result.cause == RiskCause.both);
}

/// Puntaje por síntomas del día y qué lo sumó.
class _SymptomsCard extends StatelessWidget {
  const _SymptomsCard({required this.assessment, required this.decisive});

  final SymptomAssessment? assessment;
  final bool decisive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = assessment;
    return _IndicatorCard(
      icon: Icons.checklist,
      title: 'Síntomas de hoy',
      level: value?.level,
      decisive: decisive,
      children: value == null
          ? [Text('No hay registro de hoy. Hágalo para sumar los síntomas.', style: theme.textTheme.bodyLarge)]
          : [
              Text('Puntaje: ${value.score} ${value.score == 1 ? 'punto' : 'puntos'}', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              if (value.reasons.isEmpty)
                Text('No se marcó ningún signo.', style: theme.textTheme.bodyLarge)
              else
                for (final reason in value.reasons) _Bullet(text: '${reason.label} (+${reason.points})'),
              const SizedBox(height: 8),
              Text(SymptomScore.notice, style: theme.textTheme.bodySmall),
            ],
    );
  }
}

/// Resultado del modelo LSTM, o por qué no se pudo usar.
class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.result, required this.missing, required this.decisive});

  final RiskResult? result;
  final InsufficientData? missing;
  final bool decisive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = result;
    return _IndicatorCard(
      icon: Icons.insights,
      title: 'Modelo (últimos 14 días)',
      level: value?.level,
      decisive: decisive,
      children: value == null
          ? [
              Text('Faltan datos para el modelo', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text('${missing?.message ?? ''} Mientras tanto, el semáforo se apoya en los síntomas.',
                  style: theme.textTheme.bodyLarge),
            ]
          : [
              _ProbabilityBar(probability: value.probability, level: value.level),
              const SizedBox(height: 8),
              Text('Modelo de prueba entrenado con datos simulados.', style: theme.textTheme.bodySmall),
            ],
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    required this.icon,
    required this.title,
    required this.level,
    required this.decisive,
    required this.children,
  });

  final IconData icon;
  final String title;
  final RiskLevel? level;

  /// Este indicador fijó el color final (se marca con el borde de su color).
  final bool decisive;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: decisive && level != null
              ? BorderSide(color: level!.color, width: 3)
              : const BorderSide(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                  if (level != null) RiskChip(level: level),
                ],
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.arrow_right, size: 24, color: AppColors.primary),
            ),
            const SizedBox(width: 4),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      );
}

class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({required this.probability, required this.level});

  final double probability;
  final RiskLevel level;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: probability),
        duration: Responsive.motion(context, const Duration(milliseconds: 900)),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Probabilidad estimada: ${formatPercent(value)}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: LinearProgressIndicator(value: value, minHeight: 18, color: level.color),
            ),
          ],
        ),
      );
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: AppColors.notice,
        child: Row(
          children: [
            const Icon(Icons.medical_services, color: AppColors.onNotice, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                RiskAdvice.disclaimer,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.onNotice),
              ),
            ),
          ],
        ),
      );
}
