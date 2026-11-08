import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../core/validators.dart';
import '../../data/remote/auth_api.dart';
import '../widgets/big_button.dart';
import '../widgets/notice_box.dart';
import 'auth_cubit.dart';
import 'code_field.dart';
import 'password_field.dart';
import 'password_reset_cubit.dart';
import 'resend_button.dart';

/// Recuperar la contraseña con un código enviado al correo. Necesita internet.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key, required this.api, this.initialEmail = ''});

  final AuthApi api;
  final String initialEmail;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PasswordResetCubit(api, initialEmail: initialEmail),
        child: const _ForgotPasswordView(),
      );
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView();

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _emailForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: context.read<PasswordResetCubit>().state.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _requestCode() {
    if (!_emailForm.currentState!.validate()) return;
    context.read<PasswordResetCubit>().requestCode(_email.text);
  }

  void _reset() {
    if (!_codeForm.currentState!.validate()) return;
    context.read<PasswordResetCubit>().reset(_code.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<PasswordResetCubit, PasswordResetState>(
      listenWhen: (previous, current) => previous.step != current.step,
      listener: (context, state) {
        if (state.step == PasswordResetStep.done && state.session != null) {
          // La sesión nueva reemplaza la pantalla de ingreso
          context.read<AuthCubit>().openSession(state.session!);
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      builder: (context, state) {
        final notice = state.message != null
            ? NoticeBox.error(state.message!)
            : state.info != null
                ? NoticeBox.info(state.info!)
                : null;
        final emailStep = Form(
          key: _emailForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Le enviaremos un código para crear una contraseña nueva.', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.email)),
                validator: Validators.email,
                onFieldSubmitted: (_) => _requestCode(),
              ),
              if (notice != null) ...[const SizedBox(height: 12), notice],
              const SizedBox(height: 20),
              BigButton(icon: Icons.send, label: 'Enviar código', busy: state.busy, onPressed: _requestCode),
            ],
          ),
        );
        final codeStep = Form(
          key: _codeForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Escriba el código que llegó a ${state.email} y su contraseña nueva.',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              CodeField(controller: _code, enabled: !state.busy),
              const SizedBox(height: 16),
              PasswordField(controller: _password, label: 'Contraseña nueva', validator: Validators.password),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: 'Repita la contraseña',
                validator: (v) => v == _password.text ? null : 'Las contraseñas no coinciden',
                onSubmitted: (_) => _reset(),
              ),
              if (notice != null) ...[const SizedBox(height: 12), notice],
              const SizedBox(height: 20),
              BigButton(icon: Icons.lock_reset, label: 'Cambiar contraseña', busy: state.busy, onPressed: _reset),
              const SizedBox(height: 8),
              if (state.resendAvailableAt != null)
                ResendButton(
                  availableAt: state.resendAvailableAt!,
                  busy: state.busy,
                  onPressed: context.read<PasswordResetCubit>().resend,
                ),
              TextButton.icon(
                onPressed: state.busy ? null : context.read<PasswordResetCubit>().changeEmail,
                icon: const Icon(Icons.edit),
                label: const Text('Usar otro correo'),
              ),
            ],
          ),
        );
        return Scaffold(
          appBar: AppBar(title: const Text('Recuperar contraseña')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CenteredContent(
                maxWidth: 520,
                child: state.step == PasswordResetStep.email ? emailStep : codeStep,
              ),
            ),
          ),
        );
      },
    );
  }
}
