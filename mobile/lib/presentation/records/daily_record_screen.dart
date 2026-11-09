import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../domain/entities.dart';
import '../../domain/record_estimates.dart';
import '../../domain/repositories.dart';
import '../../domain/risk_advice.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/big_button.dart';
import '../widgets/fade_in.dart';
import '../widgets/motion.dart';
import 'daily_record_cubit.dart';

/// Registro del día como asistente por preguntas: una pregunta por pantalla, todas opcionales.
class DailyRecordScreen extends StatelessWidget {
  const DailyRecordScreen({super.key, required this.cow, this.date});

  final Cow cow;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => DailyRecordCubit(
          context.read<RecordRepository>(),
          cowId: cow.id,
          date: date,
          milking: cow.productionStatus == ProductionStatus.lactating,
        )..load(),
        child: _DailyRecordView(cow: cow),
      );
}

class _Option<T> {
  const _Option(this.value, this.label, this.icon);

  final T value;
  final String label;
  final IconData icon;
}

class _DailyRecordView extends StatelessWidget {
  const _DailyRecordView({required this.cow});

  final Cow cow;

  Future<void> _pickDate(BuildContext context, DateTime current) async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: today.subtract(const Duration(days: 60)),
      lastDate: today,
      helpText: 'Día del registro',
    );
    if (picked != null && context.mounted) await context.read<DailyRecordCubit>().load(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<DailyRecordCubit, DailyRecordState>(
      listenWhen: (previous, current) => !previous.saved && current.saved,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registro de ${formatDay(state.date).toLowerCase()} guardado')),
        );
        Navigator.pop(context, true);
      },
      builder: (context, state) {
        final cubit = context.read<DailyRecordCubit>();
        final today = dateOnly(DateTime.now());
        return AppScaffold(
          title: 'Registro · ${cow.name ?? cow.tag}',
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: CenteredContent(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Progress(state: state),
                              const SizedBox(height: 8),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Text(
                                    state.date == today ? 'Día: hoy' : 'Día: ${formatDay(state.date).toLowerCase()}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  TextButton(
                                    onPressed: () => _pickDate(context, state.date),
                                    child: const Text('Cambiar día'),
                                  ),
                                ],
                              ),
                              if (state.existing != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text('Ya hay un registro para este día: puede corregirlo.',
                                      style: theme.textTheme.emphasis),
                                ),
                              const SizedBox(height: 8),
                              AnimatedSwitcher(
                                duration: Responsive.motion(context, AppMotion.page),
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(animation),
                                    child: child,
                                  ),
                                ),
                                child: KeyedSubtree(
                                  key: ValueKey(state.step),
                                  child: switch (state.step) {
                                    RecordStep.feed => _Question<FeedAnswer>(
                                        icon: Icons.grass,
                                        question: '¿Cómo comió hoy?',
                                        selected: state.answers.feed,
                                        options: const [
                                          _Option(FeedAnswer.normal, 'Normal', Icons.restaurant),
                                          _Option(FeedAnswer.less, 'Menos de lo normal', Icons.trending_down),
                                          _Option(FeedAnswer.almostNothing, 'Casi nada', Icons.no_meals),
                                          _Option(FeedAnswer.unknown, 'No sé', Icons.help_outline),
                                        ],
                                        onSelected: cubit.answerFeed,
                                      ),
                                    RecordStep.milk => _Question<MilkAnswer>(
                                        icon: Icons.water_drop,
                                        question: '¿Cuánta leche dio?',
                                        selected: state.answers.milk,
                                        options: const [
                                          _Option(MilkAnswer.same, 'Igual', Icons.water_drop),
                                          _Option(MilkAnswer.littleLess, 'Un poco menos', Icons.trending_down),
                                          _Option(MilkAnswer.muchLess, 'Mucho menos', Icons.south),
                                          _Option(MilkAnswer.unknown, 'No sé', Icons.help_outline),
                                        ],
                                        onSelected: cubit.answerMilk,
                                      ),
                                    RecordStep.body => _Question<BodyAnswer>(
                                        icon: Icons.back_hand,
                                        question: 'Al tocarla, ¿cómo siente el cuerpo?',
                                        selected: state.answers.body,
                                        options: const [
                                          _Option(BodyAnswer.normal, 'Normal', Icons.thermostat),
                                          _Option(BodyAnswer.warm, 'Tibia', Icons.device_thermostat),
                                          _Option(BodyAnswer.hot, 'Caliente', Icons.local_fire_department),
                                          _Option(BodyAnswer.unknown, 'No sé', Icons.help_outline),
                                        ],
                                        onSelected: cubit.answerBody,
                                      ),
                                    RecordStep.udder => _Question<UdderAnswer>(
                                        icon: Icons.visibility,
                                        question: '¿Cómo ve la ubre y la leche?',
                                        selected: state.answers.udder,
                                        options: const [
                                          _Option(UdderAnswer.normal, 'Todo normal', Icons.check_circle),
                                          _Option(UdderAnswer.inflamed, 'Ubre caliente, dura o hinchada',
                                              Icons.bubble_chart),
                                          _Option(UdderAnswer.abnormalMilk, 'Leche con grumos o sangre', Icons.opacity),
                                          _Option(UdderAnswer.unknown, 'No sé', Icons.help_outline),
                                        ],
                                        onSelected: cubit.answerUdder,
                                      ),
                                    RecordStep.done => _Summary(state: state),
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Controls(state: state),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const _VetNotice(),
                  ],
                ),
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final DailyRecordState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = state.step == RecordStep.done;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          done ? 'Respuestas completas' : 'Pregunta ${state.questionNumber} de ${state.steps.length}',
          style: theme.textTheme.overline,
        ),
        const SizedBox(height: 8),
        Semantics(
          label: done ? 'Registro completo' : 'Pregunta ${state.questionNumber} de ${state.steps.length}',
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: state.progress),
            duration: Responsive.motion(context, AppMotion.page),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: LinearProgressIndicator(value: value, minHeight: 10),
            ),
          ),
        ),
      ],
    );
  }
}

/// Una pregunta con sus opciones grandes. Al tocar una, el asistente pasa solo a la siguiente.
class _Question<T> extends StatelessWidget {
  const _Question({
    required this.icon,
    required this.question,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final String question;
  final List<_Option<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(question, style: theme.textTheme.headlineSmall)),
          ],
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeIn(
              index: i,
              child: _OptionCard(
                option: options[i],
                selected: options[i].value == selected,
                onTap: () => onSelected(options[i].value),
              ),
            ),
          ),
      ],
    );
  }
}

class _OptionCard<T> extends StatelessWidget {
  const _OptionCard({required this.option, required this.selected, required this.onTap});

  final _Option<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressScale(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.card,
            side: BorderSide(color: selected ? AppColors.primary : AppColors.cardBorder, width: selected ? 2.5 : 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(option.icon, size: AppSizes.icon, color: AppColors.primary),
                    const SizedBox(width: 14),
                    Expanded(child: Text(option.label, style: theme.textTheme.titleMedium)),
                    if (selected) const Icon(Icons.check, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Atrás, empezar de nuevo y saltar por hoy.
class _Controls extends StatelessWidget {
  const _Controls({required this.state});

  final DailyRecordState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DailyRecordCubit>();
    final first = state.step == state.steps.first;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 4,
      children: [
        if (!first)
          TextButton.icon(onPressed: cubit.back, icon: const Icon(Icons.arrow_back), label: const Text('Atrás')),
        if (!first)
          TextButton.icon(onPressed: cubit.restart, icon: const Icon(Icons.restart_alt), label: const Text('Empezar de nuevo')),
        TextButton.icon(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.skip_next),
          label: const Text('Saltar por hoy'),
        ),
      ],
    );
  }
}

/// Pantalla final: visto animado, valores que se guardarán (medidos o estimados) y el bloque
/// opcional de medidas exactas.
class _Summary extends StatefulWidget {
  const _Summary({required this.state});

  final DailyRecordState state;

  @override
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary> {
  final _formKey = GlobalKey<FormState>();
  late final _temperature = TextEditingController(text: _text(widget.state.answers.measuredTemperatureC));
  late final _milk = TextEditingController(text: _text(widget.state.answers.measuredMilkL));
  late final _feed = TextEditingController(text: _text(widget.state.answers.measuredFeedKg));
  late bool _exact = widget.state.answers.hasMeasurements;

  static String _text(double? value) => value == null ? '' : formatNumber(value);

  @override
  void dispose() {
    for (final c in [_temperature, _milk, _feed]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Las medidas válidas reemplazan a las estimadas mientras se escriben.
  void _measurementsChanged() {
    double? valid(TextEditingController c, FormFieldValidator<String> validator) =>
        validator(c.text) == null ? Validators.parseNumber(c.text) : null;
    context.read<DailyRecordCubit>().setMeasurements(
          temperatureC: valid(_temperature, Validators.temperatureC),
          milkL: widget.state.milking ? valid(_milk, Validators.milkL) : null,
          feedKg: valid(_feed, Validators.feedKg),
        );
  }

  void _save() {
    if (_exact && !_formKey.currentState!.validate()) return;
    _measurementsChanged();
    context.read<DailyRecordCubit>().save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final estimate = state.estimate;
    final baselines = state.baselines!;
    // Agrupado por fuente: "valores de referencia (temperatura, leche y alimento)" en vez de repetirla
    final bySource = <String, List<String>>{};
    void fallback(String value, BaselineKind kind) {
      if (kind != BaselineKind.average) bySource.putIfAbsent(kind.label, () => []).add(value);
    }
    fallback('temperatura', baselines.temperature.kind);
    if (state.milking) fallback('leche', baselines.milk.kind);
    fallback('alimento', baselines.feed.kind);
    final fallbacks = [
      for (final MapEntry(key: source, value: values) in bySource.entries) '$source (${joinSpanish(values)})',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AnimatedCheck()),
        const SizedBox(height: 12),
        Text('¡Listo!', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        Text('Revise lo que se va a guardar.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ValueRow(icon: Icons.thermostat, label: 'Temperatura', unit: '°C', value: estimate.temperature),
                if (state.milking) _ValueRow(icon: Icons.water_drop, label: 'Leche', unit: 'L', value: estimate.milk),
                _ValueRow(icon: Icons.grass, label: 'Alimento', unit: 'kg', value: estimate.feed),
                const Divider(height: 24),
                Text(
                  'Los valores estimados salen de sus respuestas y de lo normal para esta vaca. '
                  '${RecordEquivalences.notice}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (fallbacks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: AppColors.highlightSurface, borderRadius: AppRadius.field),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.warningText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta vaca todavía no tiene historial suficiente; para estimar se usaron '
                    '${joinSpanish(fallbacks)}.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.warningText),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                value: _exact,
                onChanged: (value) {
                  setState(() => _exact = value);
                  if (!value) {
                    for (final c in [_temperature, _milk, _feed]) {
                      c.clear();
                    }
                    _measurementsChanged();
                  }
                },
                secondary: const Icon(Icons.straighten),
                title: const Text('Tengo termómetro o litros exactos'),
                subtitle: const Text('Opcional: si los tiene, se usan en lugar de los estimados.'),
              ),
              AnimatedSize(
                duration: Responsive.motion(context, AppMotion.page),
                child: !_exact
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _NumberField(
                                controller: _temperature,
                                label: 'Temperatura (opcional)',
                                unit: '°C',
                                hint: 'Ej.: 38,6',
                                icon: Icons.thermostat,
                                validator: Validators.temperatureC,
                                onChanged: _measurementsChanged,
                              ),
                              if (state.milking) ...[
                                const SizedBox(height: 12),
                                _NumberField(
                                  controller: _milk,
                                  label: 'Leche del día (opcional)',
                                  unit: 'L',
                                  hint: 'Ej.: 12,5',
                                  icon: Icons.water_drop,
                                  validator: Validators.milkL,
                                  onChanged: _measurementsChanged,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _NumberField(
                                controller: _feed,
                                label: 'Alimento consumido (opcional)',
                                unit: 'kg',
                                hint: 'Ej.: 10',
                                icon: Icons.grass,
                                validator: Validators.feedKg,
                                onChanged: _measurementsChanged,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BigButton(icon: Icons.save, label: 'Guardar registro', busy: state.saving, onPressed: _save),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.icon, required this.label, required this.unit, required this.value});

  final IconData icon;
  final String label;
  final String unit;
  final EstimatedValue? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final measured = value?.source == ValueSource.measured;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value == null ? '$label: sin dato' : '$label: ${formatNumber(value!.value)} $unit',
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (value != null) SourceChip(measured: measured),
        ],
      ),
    );
  }
}

/// Rótulo "medido" o "estimado" de un valor del registro.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.measured});

  final bool measured;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: measured ? AppColors.primarySoft : AppColors.highlightSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          measured ? ValueSource.measured.label : ValueSource.estimated.label,
          style: Theme.of(context)
              .textTheme
              .chip
              .copyWith(color: measured ? AppColors.riskGreenText : AppColors.warningText),
        ),
      );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.hint,
    required this.icon,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: Theme.of(context).textTheme.numberInput,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: 'Déjelo vacío si no lo midió',
          prefixIcon: Icon(icon, size: AppSizes.icon),
          suffixText: unit,
          suffixStyle: Theme.of(context).textTheme.numberUnit,
        ),
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) => onChanged(),
      );
}

/// Aviso fijo: la app apoya, no reemplaza al veterinario.
class _VetNotice extends StatelessWidget {
  const _VetNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: AppColors.notice,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const Icon(Icons.medical_services, color: AppColors.onNotice),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  RiskAdvice.disclaimer,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.onNotice),
                ),
              ),
            ],
          ),
        ),
      );
}
