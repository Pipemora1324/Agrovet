import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Campo para el código de 6 números del correo: dígitos grandes y teclado numérico.
/// Avisa con [onCompleted] apenas se escriben los 6 números.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.onCompleted, this.enabled = true});

  static const length = 6;

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool enabled;

  static String? validate(String? value) =>
      value != null && RegExp(r'^\d{6}$').hasMatch(value.trim()) ? null : 'Escriba los 6 números del código';

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        enabled: enabled,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: length,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: Theme.of(context).textTheme.code,
        decoration: const InputDecoration(labelText: 'Código', counterText: '', hintText: '000000'),
        validator: validate,
        onChanged: (value) {
          if (value.length == length) onCompleted?.call(value);
        },
      );
}
