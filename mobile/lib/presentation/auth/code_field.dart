import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';

/// Código de 6 números del correo, en 6 casillas grandes. Un solo campo de texto invisible recibe
/// lo que se escribe (así funcionan el teclado numérico y el autocompletado del código).
/// Avisa con [onCompleted] apenas se escriben los 6 números.
class CodeField extends StatefulWidget {
  const CodeField({super.key, required this.controller, this.onCompleted, this.enabled = true});

  static const length = 6;

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool enabled;

  static String? validate(String? value) =>
      value != null && RegExp(r'^\d{6}$').hasMatch(value.trim()) ? null : 'Escriba los 6 números del código';

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(CodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;
    return FormField<String>(
      validator: (_) => CodeField.validate(widget.controller.text),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Código',
            value: text,
            textField: true,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < CodeField.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _Box(
                          digit: i < text.length ? text[i] : null,
                          active: _focus.hasFocus && i == text.length.clamp(0, CodeField.length - 1),
                          error: field.hasError,
                          enabled: widget.enabled,
                        ),
                      ),
                    ],
                  ],
                ),
                // Campo real: invisible, encima de las casillas, para recibir los toques y el texto
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: CodeField.length,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      showCursor: false,
                      enableInteractiveSelection: false,
                      style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.transparent),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        field.didChange(value);
                        if (value.length == CodeField.length) widget.onCompleted?.call(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (field.hasError) ...[
            const SizedBox(height: 8),
            Text(field.errorText!, style: theme.textTheme.formError),
          ],
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.error, required this.enabled});

  final String? digit;
  final bool active;
  final bool error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? AppColors.error
        : active || digit != null
            ? AppColors.primary
            : AppColors.outline;
    return AnimatedContainer(
      duration: Responsive.motion(context, AppMotion.press),
      constraints: const BoxConstraints(minHeight: 64),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? (digit != null ? AppColors.primarySoft : AppColors.surface) : AppColors.riskNone,
        borderRadius: AppRadius.field,
        border: Border.all(color: borderColor, width: active ? 3 : 1.5),
      ),
      child: Text(digit ?? '', style: Theme.of(context).textTheme.code),
    );
  }
}
