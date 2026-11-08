import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/big_button.dart';
import 'daily_record_cubit.dart';

class DailyRecordScreen extends StatelessWidget {
  const DailyRecordScreen({super.key, required this.cow, this.date});

  final Cow cow;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) =>
            DailyRecordCubit(context.read<RecordRepository>(), cowId: cow.id, date: date)..load(),
        child: _DailyRecordView(cow: cow),
      );
}

class _DailyRecordView extends StatefulWidget {
  const _DailyRecordView({required this.cow});

  final Cow cow;

  @override
  State<_DailyRecordView> createState() => _DailyRecordViewState();
}

class _DailyRecordViewState extends State<_DailyRecordView> {
  final _formKey = GlobalKey<FormState>();
  final _temperature = TextEditingController();
  final _milk = TextEditingController();
  final _feed = TextEditingController();
  final _notes = TextEditingController();
  String? _formError;

  @override
  void dispose() {
    for (final c in [_temperature, _milk, _feed, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(DailyRecord? record) {
    String text(double? v) => v == null ? '' : formatNumber(v);
    _temperature.text = text(record?.temperatureC);
    _milk.text = text(record?.milkL);
    _feed.text = text(record?.feedKg);
    _notes.text = record?.notes ?? '';
    _formError = null;
  }

  Future<void> _pickDate(DateTime current) async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: today.subtract(const Duration(days: 60)),
      lastDate: today,
      helpText: 'Día del registro',
    );
    if (picked != null && mounted) context.read<DailyRecordCubit>().load(picked);
  }

  void _save(DailyRecordState state) {
    if (!_formKey.currentState!.validate()) return;
    final temperature = Validators.parseNumber(_temperature.text);
    final milk = Validators.parseNumber(_milk.text);
    final feed = Validators.parseNumber(_feed.text);
    if (temperature == null && milk == null && feed == null && !state.symptoms.anyAnswer) {
      setState(() => _formError = 'Responda una pregunta, marque un signo o escriba una medición.');
      return;
    }
    setState(() => _formError = null);
    context.read<DailyRecordCubit>().save(temperatureC: temperature, milkL: milk, feedKg: feed, notes: _notes.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<DailyRecordCubit, DailyRecordState>(
      listenWhen: (previous, current) =>
          (previous.loading && !current.loading) || (!previous.saved && current.saved),
      listener: (context, state) {
        if (state.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registro de ${formatDay(state.date).toLowerCase()} guardado')),
          );
          Navigator.pop(context);
        } else {
          setState(() => _fill(state.existing));
        }
      },
      builder: (context, state) {
        final today = dateOnly(DateTime.now());
        final yesterday = today.subtract(const Duration(days: 1));
        return AppScaffold(
          title: 'Registro · ${widget.cow.name ?? widget.cow.tag}',
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: CenteredContent(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DayChip(
                                label: 'Hoy',
                                selected: state.date == today,
                                onTap: () => context.read<DailyRecordCubit>().load(today),
                              ),
                              _DayChip(
                                label: 'Ayer',
                                selected: state.date == yesterday,
                                onTap: () => context.read<DailyRecordCubit>().load(yesterday),
                              ),
                              _DayChip(
                                label: state.date.isBefore(yesterday) ? formatDay(state.date) : 'Otro día',
                                icon: Icons.calendar_month,
                                selected: state.date.isBefore(yesterday),
                                onTap: () => _pickDate(state.date),
                              ),
                            ],
                          ),
                          if (state.existing != null) ...[
                            const SizedBox(height: 12),
                            Text('Ya hay un registro para este día: puede corregirlo.',
                                style: theme.textTheme.emphasis),
                          ],
                          const SizedBox(height: 20),
                          _YesNoQuestion(
                            question: '¿Comió normal hoy?',
                            icon: Icons.grass,
                            value: state.symptoms.ateNormally,
                            onChanged: (value) => context
                                .read<DailyRecordCubit>()
                                .updateSymptoms(state.symptoms.copyWith(ateNormally: () => value)),
                          ),
                          const SizedBox(height: 12),
                          _YesNoQuestion(
                            question: '¿Dio menos leche de lo usual?',
                            icon: Icons.water_drop,
                            value: state.symptoms.milkDrop,
                            onChanged: (value) => context
                                .read<DailyRecordCubit>()
                                .updateSymptoms(state.symptoms.copyWith(milkDrop: () => value)),
                          ),
                          const SizedBox(height: 24),
                          Text('¿Ve alguno de estos signos en la ubre?', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _SymptomsChecklist(
                            symptoms: state.symptoms,
                            onChanged: context.read<DailyRecordCubit>().updateSymptoms,
                          ),
                          const SizedBox(height: 24),
                          Text('Mediciones (opcionales)', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Si las toma, el modelo puede estimar el riesgo con más precisión.',
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          _NumberField(
                            controller: _temperature,
                            label: 'Temperatura (opcional)',
                            unit: '°C',
                            hint: 'Ej.: 38,6',
                            icon: Icons.thermostat,
                            validator: Validators.temperatureC,
                          ),
                          const SizedBox(height: 16),
                          _NumberField(
                            controller: _milk,
                            label: 'Leche del día (opcional)',
                            unit: 'L',
                            hint: 'Ej.: 12,5',
                            icon: Icons.water_drop,
                            validator: Validators.milkL,
                          ),
                          const SizedBox(height: 16),
                          _NumberField(
                            controller: _feed,
                            label: 'Alimento consumido (opcional)',
                            unit: 'kg',
                            hint: 'Ej.: 10',
                            icon: Icons.grass,
                            validator: Validators.feedKg,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notes,
                            maxLength: 500,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Notas (opcional)', prefixIcon: Icon(Icons.notes)),
                          ),
                          if (_formError != null) ...[
                            const SizedBox(height: 8),
                            Text(_formError!, style: theme.textTheme.formError),
                          ],
                          const SizedBox(height: 20),
                          BigButton(
                            icon: Icons.save,
                            label: 'Guardar registro',
                            busy: state.saving,
                            onPressed: () => _save(state),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onPrimary : AppColors.ink;
    return ChoiceChip(
      label: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: foreground)),
      avatar: icon == null ? null : Icon(icon, color: foreground),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.hint,
    required this.icon,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: Theme.of(context).textTheme.numberInput,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: 'Déjelo vacío si hoy no lo midió',
          prefixIcon: Icon(icon, size: 28),
          suffixText: unit,
          suffixStyle: Theme.of(context).textTheme.numberUnit,
        ),
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      );
}

class _SymptomsChecklist extends StatelessWidget {
  const _SymptomsChecklist({required this.symptoms, required this.onChanged});

  final Symptoms symptoms;
  final ValueChanged<Symptoms> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Enrojecida', Icons.flare, symptoms.udderRedness, (bool v) => symptoms.copyWith(udderRedness: v)),
      ('Hinchada', Icons.bubble_chart, symptoms.udderSwelling, (bool v) => symptoms.copyWith(udderSwelling: v)),
      ('Caliente', Icons.local_fire_department, symptoms.udderHeat, (bool v) => symptoms.copyWith(udderHeat: v)),
      ('Dolor al tocar', Icons.back_hand, symptoms.udderPain, (bool v) => symptoms.copyWith(udderPain: v)),
      ('Grumos o sangre en la leche', Icons.opacity, symptoms.abnormalMilk,
          (bool v) => symptoms.copyWith(abnormalMilk: v)),
    ];
    return Column(
      children: [
        for (final (label, icon, value, update) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnimatedContainer(
              duration: Responsive.motion(context, const Duration(milliseconds: 200)),
              decoration: BoxDecoration(
                color: value ? AppColors.highlightSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(color: value ? AppColors.highlightBorder : AppColors.outlineSoft, width: 2),
              ),
              // Material propio para que el efecto al tocar se vea sobre el fondo de color
              child: Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  value: value,
                  onChanged: (v) => onChanged(update(v ?? false)),
                  secondary: Icon(icon, size: 30, color: AppColors.ink),
                  title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  controlAffinity: ListTileControlAffinity.trailing,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pregunta de Sí o No. Se puede dejar sin responder; tocar de nuevo la respuesta elegida la borra.
class _YesNoQuestion extends StatelessWidget {
  const _YesNoQuestion({required this.question, required this.icon, required this.value, required this.onChanged});

  final String question;
  final IconData icon;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 28, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(question, style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: true, label: Text('Sí'), icon: Icon(Icons.check)),
              ButtonSegment(value: false, label: Text('No'), icon: Icon(Icons.close)),
            ],
            selected: {?value},
            onSelectionChanged: (selection) => onChanged(selection.isEmpty ? null : selection.first),
          ),
        ],
      );
}
