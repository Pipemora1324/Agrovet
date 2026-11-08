import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../core/validators.dart';
import '../auth/password_field.dart';
import '../widgets/big_button.dart';
import '../widgets/notice_box.dart';
import 'profile_cubit.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<ProfileCubit>();
    if (await cubit.changePassword(_current.text, _password.text) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cubit.state.message!)));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProfileCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: CenteredContent(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    controller: _current,
                    label: 'Contraseña actual',
                    newPassword: false,
                    validator: (v) => v == null || v.isEmpty ? 'Escriba su contraseña actual' : null,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(controller: _password, label: 'Contraseña nueva', validator: Validators.password),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _confirm,
                    label: 'Repita la contraseña nueva',
                    validator: (v) => v == _password.text ? null : 'Las contraseñas no coinciden',
                    onSubmitted: (_) => _submit(),
                  ),
                  if (state.error != null) ...[const SizedBox(height: 12), NoticeBox.error(state.error!)],
                  const SizedBox(height: 20),
                  BigButton(icon: Icons.lock_reset, label: 'Cambiar contraseña', busy: state.busy, onPressed: _submit),
                  const SizedBox(height: 12),
                  Text(
                    'Necesita internet. Por seguridad, se cerrará la sesión en los demás celulares.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
