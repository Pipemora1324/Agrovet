import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../widgets/big_button.dart';
import '../widgets/fade_in.dart';
import '../widgets/notice_box.dart';
import 'auth_cubit.dart';
import 'code_field.dart';
import 'resend_button.dart';

/// Pantalla para escribir el código que llegó al correo. Necesita internet.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  /// El servidor acepta 5 intentos por código; se cuentan los rechazados desde el último envío.
  static const maxAttempts = 5;
  int _failed = 0;
  DateTime? _codeSentAt;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().verify(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final state = context.watch<AuthCubit>().state;
    if (state is! AwaitingVerification) return const SizedBox.shrink();
    _codeSentAt ??= state.resendAvailableAt;
    final theme = Theme.of(context);
    final attemptsLeft = maxAttempts - _failed;

    return BlocListener<AuthCubit, AuthState>(
      // Un código incorrecto se borra para escribir el siguiente; un código nuevo reinicia los intentos
      listenWhen: (previous, current) => current is AwaitingVerification && previous != current,
      listener: (context, current) {
        final now = current as AwaitingVerification;
        if (_codeSentAt != now.resendAvailableAt) {
          _codeSentAt = now.resendAvailableAt;
          setState(() => _failed = 0);
        } else if (now.message != null && !now.busy) {
          _code.clear();
          setState(() => _failed = (_failed + 1).clamp(0, maxAttempts));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verificar correo'),
          leading: IconButton(
            tooltip: 'Volver al ingreso',
            icon: const Icon(Icons.arrow_back),
            onPressed: state.busy ? null : cubit.cancelVerification,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: CenteredContent(
              maxWidth: 520,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeIn(
                      child: Icon(Icons.mark_email_read, size: 72, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('Revise su correo', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Escriba el código de 6 números que enviamos a ${state.email}. Vence en 15 minutos.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    CodeField(controller: _code, enabled: !state.busy, onCompleted: (_) => _submit()),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: attemptsLeft <= 2 ? AppColors.warningText : AppColors.inkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attemptsLeft <= 0
                                ? 'Se acabaron los intentos con este código. Pida uno nuevo.'
                                : 'Le quedan $attemptsLeft de $maxAttempts intentos con este código.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: attemptsLeft <= 2 ? AppColors.warningText : AppColors.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    if (state.message != null) ...[
                      const SizedBox(height: 12),
                      NoticeBox.error(state.message!),
                    ] else if (state.info != null) ...[
                      const SizedBox(height: 12),
                      NoticeBox.info(state.info!),
                    ],
                    const SizedBox(height: 20),
                    BigButton(icon: Icons.verified, label: 'Verificar', busy: state.busy, onPressed: _submit),
                    const SizedBox(height: 8),
                    ResendButton(
                      availableAt: state.resendAvailableAt,
                      busy: state.busy,
                      onPressed: cubit.resendCode,
                    ),
                    TextButton.icon(
                      onPressed: state.busy ? null : cubit.cancelVerification,
                      icon: const Icon(Icons.edit),
                      label: const Text('Corregir el correo'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Necesita internet para verificar la cuenta. Después, la app funciona sin conexión.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
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
