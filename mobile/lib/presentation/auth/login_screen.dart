import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../widgets/big_button.dart';
import '../widgets/fade_in.dart';
import 'auth_cubit.dart';

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
  bool _showPassword = false;

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
      auth.register(_name.text, _email.text, _password.text);
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
                  const SizedBox(height: 24),
                  FadeIn(
                    child: Column(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.health_and_safety, color: Colors.white, size: 56),
                        ),
                        const SizedBox(height: 16),
                        Text('AgroVet', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Alerta temprana de mastitis',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedSize(
                    duration: Responsive.motion(context, const Duration(milliseconds: 250)),
                    child: _registering
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person)),
                              validator: (v) => Validators.requiredText(v, 'Escriba su nombre'),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.email)),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: !_showPassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: Validators.password,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    FadeIn(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(message,
                                  style: TextStyle(fontSize: 16, color: theme.colorScheme.onErrorContainer)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  BigButton(
                    icon: _registering ? Icons.person_add : Icons.login,
                    label: _registering ? 'Crear cuenta' : 'Ingresar',
                    busy: busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : () => setState(() => _registering = !_registering),
                    child: Text(_registering ? 'Ya tengo cuenta: ingresar' : 'No tengo cuenta: crear una'),
                  ),
                  if (context.read<AuthCubit>().allowDemo) ...[
                    const Divider(height: 32),
                    BigButton(
                      icon: Icons.science_outlined,
                      label: 'Ver con datos de demostración',
                      outlined: true,
                      onPressed: busy ? null : context.read<AuthCubit>().enterDemo,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Solo en la versión de prueba. Los datos son inventados y no se sincronizan.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
