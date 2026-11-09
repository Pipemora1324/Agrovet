import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../widgets/big_button.dart';
import '../widgets/fade_in.dart';
import '../widgets/motion.dart';
import '../profile/privacy_notice_screen.dart';
import '../widgets/notice_box.dart';
import 'auth_cubit.dart';
import 'forgot_password_screen.dart';
import 'password_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _acceptedPrivacy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthCubit>();
    if (_registering) {
      auth.register(
        _name.text,
        _email.text,
        _password.text,
        acceptedPrivacy: _acceptedPrivacy,
      );
    } else {
      auth.login(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final busy = state is Unauthenticated && state.busy;
    final message = state is Unauthenticated ? state.message : null;
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CurvedHero(
              minHeight: 260,
              child: SafeArea(
                bottom: false,
                child: CenteredContent(
                  maxWidth: 520,
                  child: FadeIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.health_and_safety,
                            color: AppColors.primary,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('AgroVet', style: theme.textTheme.heroTitle),
                        const SizedBox(height: 4),
                        Text(
                          _registering
                              ? 'Cree su cuenta para respaldar sus vacas.'
                              : 'Alerta temprana de mastitis, también sin internet.',
                          style: theme.textTheme.heroBody,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: CenteredContent(
                maxWidth: 520,
                child: FadeIn(
                  index: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _form(context, busy: busy, message: message),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, {required bool busy, String? message}) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _registering ? 'Cuenta nueva' : 'Bienvenido de nuevo',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: Responsive.motion(
              context,
              const Duration(milliseconds: 250),
            ),
            child: _registering
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) =>
                          Validators.requiredText(v, 'Escriba su nombre'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.email),
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _password,
            label: 'Contraseña',
            newPassword: _registering,
            validator: Validators.password,
            onSubmitted: (_) => _submit(),
          ),
          if (_registering) ...[
            const SizedBox(height: 12),
            _PrivacyConsent(
              value: _acceptedPrivacy,
              onChanged: (value) => setState(() => _acceptedPrivacy = value),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 16),
            FadeIn(child: NoticeBox.error(message)),
          ],
          const SizedBox(height: 24),
          ShineButton(
            icon: _registering ? Icons.person_add : Icons.login,
            label: _registering ? 'Crear cuenta' : 'Ingresar',
            busy: busy,
            onPressed: _submit,
          ),
          if (_registering) ...[
            const SizedBox(height: 8),
            Text(
              'Le enviaremos un código al correo para confirmar que es suyo. Necesita internet para '
              'crear la cuenta; después, la app funciona sin conexión.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ] else
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          api: context.read<AuthCubit>().api,
                          initialEmail: _email.text,
                        ),
                      ),
                    ),
              child: const Text('Olvidé mi contraseña'),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() => _registering = !_registering),
            child: Text(
              _registering
                  ? 'Ya tengo cuenta: ingresar'
                  : 'No tengo cuenta: crear una',
            ),
          ),
          if (kDebugMode && context.read<AuthCubit>().allowDemo) ...[
            const Divider(height: 32),
            BigButton(
              icon: Icons.science_outlined,
              label: 'Entrar a la demostración',
              outlined: true,
              onPressed: busy ? null : context.read<AuthCubit>().enterDemo,
            ),
          ],
        ],
      ),
    );
  }
}

/// Autorización de tratamiento de datos (Ley 1581 de 2012): casilla obligatoria y enlace al aviso.
class _PrivacyConsent extends StatelessWidget {
  const _PrivacyConsent({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => FormField<bool>(
    initialValue: value,
    validator: (_) => value
        ? null
        : 'Debe aceptar el aviso de privacidad para crear la cuenta',
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: value,
          onChanged: (checked) {
            onChanged(checked ?? false);
            field.didChange(checked);
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Leí y acepto el aviso de privacidad y autorizo el tratamiento de mis datos.',
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyNoticeScreen()),
            ),
            icon: const Icon(Icons.privacy_tip),
            label: const Text('Leer el aviso de privacidad'),
          ),
        ),
        if (field.hasError)
          Text(field.errorText!, style: Theme.of(context).textTheme.formError),
      ],
    ),
  );
}
