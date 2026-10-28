import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/responsive.dart';
import '../../core/validators.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/big_button.dart';
import 'cows_cubit.dart';

class CowFormScreen extends StatefulWidget {
  const CowFormScreen({super.key, this.cow});

  /// Vaca a editar; null para crear una nueva.
  final Cow? cow;

  @override
  State<CowFormScreen> createState() => _CowFormScreenState();
}

class _CowFormScreenState extends State<CowFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tag = TextEditingController(text: widget.cow?.tag);
  late final _name = TextEditingController(text: widget.cow?.name);
  late final _breed = TextEditingController(text: widget.cow?.breed);
  late final _calvings = TextEditingController(text: widget.cow?.calvings?.toString());
  late DateTime? _birthDate = widget.cow?.birthDate;
  late ProductionStatus _status = widget.cow?.productionStatus ?? ProductionStatus.lactating;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_tag, _name, _breed, _calvings]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 4, now.month, now.day),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await CowEditor(context.read<CowRepository>()).save(
      existing: widget.cow,
      tag: _tag.text,
      name: _name.text,
      breed: _breed.text,
      birthDate: _birthDate,
      calvings: int.tryParse(_calvings.text.trim()),
      status: _status,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.cow == null ? 'Vaca agregada' : 'Cambios guardados')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.cow != null;
    return AppScaffold(
      title: editing ? 'Editar vaca' : 'Nueva vaca',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: CenteredContent(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _tag,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Identificador (arete) *',
                    helperText: 'Número o código que la identifica en la finca',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  maxLength: 40,
                  validator: (v) => Validators.requiredText(v, 'El identificador es obligatorio'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.badge)),
                  maxLength: 80,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _breed,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Raza', prefixIcon: Icon(Icons.category)),
                  maxLength: 60,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickBirthDate,
                  icon: const Icon(Icons.cake),
                  label: Text(_birthDate == null
                      ? 'Fecha de nacimiento (opcional)'
                      : 'Nació el ${DateFormat("d 'de' MMMM 'de' y", 'es').format(_birthDate!)}'),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _calvings,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Número de partos', prefixIcon: Icon(Icons.child_care)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    return n == null || n < 0 || n > 30 ? 'Escriba un número entre 0 y 30' : null;
                  },
                ),
                const SizedBox(height: 20),
                Text('Estado productivo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<ProductionStatus>(
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size(64, 60),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  segments: [
                    for (final status in ProductionStatus.values)
                      ButtonSegment(value: status, label: Text(status.label)),
                  ],
                  selected: {_status},
                  onSelectionChanged: (selection) => setState(() => _status = selection.first),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 17, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 28),
                BigButton(icon: Icons.save, label: 'Guardar', busy: _saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
