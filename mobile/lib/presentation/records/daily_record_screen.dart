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
    if (temperature == null && milk == null && feed == null && !state.symptoms.any) {
      setState(() => _formError = 'Escriba al menos un dato o marque un síntoma.');
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
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 20),
                          _NumberField(
                            controller: _temperature,
                            label: 'Temperatura',
                            unit: '°C',
                            hint: 'Ej.: 38,6',
                            icon: Icons.thermostat,
                            validator: Validators.temperatureC,
                          ),
                          const SizedBox(height: 16),
                          _NumberField(
                            controller: _milk,
                            label: 'Leche del día',
                            unit: 'L',
                            hint: 'Ej.: 12,5',
                            icon: Icons.water_drop,
                            validator: Validators.milkL,
                          ),
                          const SizedBox(height: 16),
                          _NumberField(
                            controller: _feed,
                            label: 'Alimento consumido',
                            unit: 'kg',
                            hint: 'Ej.: 10',
                            icon: Icons.grass,
                            validator: Validators.feedKg,
                          ),
                          const SizedBox(height: 24),
                          Text('¿Ve alguno de estos síntomas?', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _SymptomsChecklist(
                            symptoms: state.symptoms,
                            onChanged: context.read<DailyRecordCubit>().updateSymptoms,
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
                            Text(_formError!,
                                style: TextStyle(
                                    color: theme.colorScheme.error, fontSize: 17, fontWeight: FontWeight.w700)),
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
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.ink)),
        avatar: icon == null ? null : Icon(icon, color: selected ? Colors.white : AppTheme.ink),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onSelected: (_) => onTap(),
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
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 28),
          suffixText: unit,
          suffixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.ink),
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
      ('Ubre hinchada o caliente', Icons.local_fire_department, symptoms.udderSwelling,
          (bool v) => symptoms.copyWith(udderSwelling: v)),
      ('Leche con grumos, sangre o aguada', Icons.opacity, symptoms.abnormalMilk,
          (bool v) => symptoms.copyWith(abnormalMilk: v)),
      ('Dolor al tocar o al ordeñar', Icons.back_hand, symptoms.udderPain, (bool v) => symptoms.copyWith(udderPain: v)),
      ('Decaída, come poco', Icons.bedtime, symptoms.lethargy, (bool v) => symptoms.copyWith(lethargy: v)),
    ];
    return Column(
      children: [
        for (final (label, icon, value, update) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnimatedContainer(
              duration: Responsive.motion(context, const Duration(milliseconds: 200)),
              decoration: BoxDecoration(
                color: value ? const Color(0xFFFFF3CD) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: value ? const Color(0xFFB07A00) : const Color(0xFFC9D0C2), width: 2),
              ),
              // Material propio para que el efecto al tocar se vea sobre el fondo de color
              child: Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  value: value,
                  onChanged: (v) => onChanged(update(v ?? false)),
                  secondary: Icon(icon, size: 30, color: AppTheme.ink),
                  title: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  controlAffinity: ListTileControlAffinity.trailing,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
