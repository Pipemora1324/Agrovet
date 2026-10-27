import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../../domain/risk_advice.dart';
import '../../domain/risk_evaluator.dart';
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
                  RiskState(outcome: final InsufficientData data) =>
                    _Insufficient(key: const ValueKey('insufficient'), data: data, cow: cow),
                  RiskState(outcome: final RiskResult result) =>
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

class _Insufficient extends StatelessWidget {
  const _Insufficient({super.key, required this.data, required this.cow});

  final InsufficientData data;
  final Cow cow;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: CenteredContent(
          maxWidth: 560,
          child: FadeIn(
            child: Column(
              children: [
                const Icon(Icons.event_busy, size: 72, color: Color(0xFF7A5600)),
                const SizedBox(height: 16),
                Text('Faltan registros', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(data.message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
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

  final RiskResult result;
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
            decoration: BoxDecoration(color: level.color, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(level.icon, color: level.onColor, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(level.label,
                      style: TextStyle(color: level.onColor, fontSize: 26, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeIn(index: 2, child: _ProbabilityBar(probability: result.probability, level: level)),
        const SizedBox(height: 20),
        FadeIn(
          index: 3,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(advice.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final step in advice.steps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(Icons.arrow_right, size: 24, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 4),
                          Expanded(child: Text(step, style: theme.textTheme.bodyLarge)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Evaluado con los registros hasta ${formatDay(result.windowEnd).toLowerCase()}. '
          'Modelo de prueba entrenado con datos simulados.',
          style: theme.textTheme.bodyMedium,
        ),
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
            Text('Probabilidad estimada: ${formatPercent(value)}',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 18,
                color: level.color,
                backgroundColor: const Color(0xFFE3E7DF),
              ),
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
        color: const Color(0xFF263238),
        child: const Row(
          children: [
            Icon(Icons.medical_services, color: Colors.white, size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                RiskAdvice.disclaimer,
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
