import 'package:flutter/material.dart';

/// Campo de contraseña con botón para mostrarla u ocultarla.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onSubmitted,
    this.newPassword = true,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  /// true: el sistema puede sugerir una contraseña nueva; false: la contraseña actual.
  final bool newPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: !_visible,
        autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
            icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ),
        validator: widget.validator,
        onFieldSubmitted: widget.onSubmitted,
      );
}
