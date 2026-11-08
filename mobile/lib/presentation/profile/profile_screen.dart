import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/local/local_data_wiper.dart';
import '../../data/remote/profile_api.dart';
import '../../domain/privacy_notice.dart';
import '../../domain/session.dart';
import '../auth/auth_cubit.dart';
import '../auth/password_field.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/big_button.dart';
import '../widgets/notice_box.dart';
import 'change_password_screen.dart';
import 'privacy_notice_screen.dart';
import 'profile_cubit.dart';

/// Mi perfil: datos de la cuenta, contraseña, privacidad, cerrar sesión y eliminar la cuenta.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => ProfileCubit(
          api: context.read<ProfileApi>(),
          auth: context.read<AuthCubit>(),
          wiper: context.read<LocalDataWiper>(),
        )..refresh(),
        child: const _ProfileView(),
      );
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _farm = TextEditingController();
  final _municipality = TextEditingController();
  final _phone = TextEditingController();
  Session? _filledFrom;

  @override
  void dispose() {
    for (final c in [_name, _farm, _municipality, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Llena el formulario con el perfil guardado (y otra vez si llega uno nuevo del servidor).
  void _fill(Session session) {
    if (_filledFrom?.withTokens(accessToken: '', refreshToken: '') ==
        session.withTokens(accessToken: '', refreshToken: '')) {
      return;
    }
    _filledFrom = session;
    _name.text = session.name;
    _farm.text = session.farmName ?? '';
    _municipality.text = session.municipality ?? '';
    _phone.text = session.phone ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<ProfileCubit>();
    if (await cubit.save(
          name: _name.text,
          farmName: _farm.text,
          municipality: _municipality.text,
          phone: _phone.text,
        ) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cubit.state.message!)));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Sus datos quedan guardados y cifrados en este celular.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmed == true && mounted) await context.read<AuthCubit>().logout();
  }

  Future<void> _confirmDelete() async {
    final cubit = context.read<ProfileCubit>();
    final password = await showDialog<String>(context: context, builder: (_) => const _DeleteAccountDialog());
    if (password == null || !mounted) return;
    await cubit.deleteAccount(password);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    if (authState is! Authenticated) return const SizedBox.shrink();
    final session = authState.session;
    _fill(session);
    final state = context.watch<ProfileCubit>().state;
    final theme = Theme.of(context);
    final needsConsent = !session.isDemo && session.privacyPolicyVersion != PrivacyNotice.version;

    return AppScaffold(
      title: 'Mi perfil',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: Text(session.name.isEmpty ? '?' : session.name.characters.first.toUpperCase(),
                          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary)),
                    ),
                    title: Text(session.name, style: theme.textTheme.titleMedium),
                    subtitle: Text(session.email),
                  ),
                ),
                if (needsConsent) ...[
                  const SizedBox(height: 16),
                  _ConsentCard(busy: state.busy, onAccept: context.read<ProfileCubit>().acceptPrivacy),
                ],
                const SizedBox(height: 20),
                Text('Datos de la cuenta', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person)),
                        validator: (v) => Validators.requiredText(v, 'Escriba su nombre'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _farm,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: 'Finca (opcional)', prefixIcon: Icon(Icons.agriculture)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _municipality,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 80,
                        decoration: const InputDecoration(
                            labelText: 'Municipio (opcional)', prefixIcon: Icon(Icons.location_city)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(labelText: 'Teléfono (opcional)', prefixIcon: Icon(Icons.phone)),
                        validator: Validators.phone,
                      ),
                    ],
                  ),
                ),
                if (state.error != null) ...[const SizedBox(height: 12), NoticeBox.error(state.error!)],
                const SizedBox(height: 16),
                BigButton(icon: Icons.save, label: 'Guardar cambios', busy: state.busy, onPressed: _save),
                const SizedBox(height: 4),
                Text('Para guardar cambios necesita internet.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock),
                        title: const Text('Cambiar contraseña'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: session.isDemo
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<ProfileCubit>(),
                                      child: const ChangePasswordScreen(),
                                    ),
                                  ),
                                ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip),
                        title: const Text(PrivacyNotice.title),
                        subtitle: Text(session.privacyPolicyVersion == null
                            ? 'Sin aceptar'
                            : 'Aceptado (versión ${session.privacyPolicyVersion})'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const PrivacyNoticeScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                BigButton(icon: Icons.logout, label: 'Cerrar sesión', outlined: true, onPressed: _confirmLogout),
                const SizedBox(height: 32),
                Text('Zona de peligro', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: AppButtonStyles.dangerOutlined(context),
                  onPressed: session.isDemo || state.busy ? null : _confirmDelete,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Eliminar mi cuenta'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Borra para siempre su cuenta y todos sus datos, en el servidor y en este celular.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide aceptar el aviso de privacidad a las cuentas anteriores a él (o si cambió de versión).
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.busy, required this.onAccept});

  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) => Card(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: AppColors.highlightBorder, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Falta su autorización', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Lea el aviso de privacidad y confirme que autoriza el tratamiento de sus datos.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyNoticeScreen())),
                child: const Text('Leer el aviso'),
              ),
              BigButton(icon: Icons.check, label: 'Acepto', busy: busy, onPressed: onAccept),
            ],
          ),
        ),
      );
}

/// Confirmación fuerte: explica qué se borra y pide la contraseña.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      icon: Icon(Icons.warning_rounded, color: error, size: 40),
      title: const Text('¿Eliminar su cuenta?'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Se borrarán para siempre su cuenta, sus vacas, registros, alertas y fotos, en el servidor '
                'y en este celular. No se puede deshacer.',
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Su contraseña',
                newPassword: false,
                validator: (v) => v == null || v.isEmpty ? 'Escriba su contraseña para confirmar' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: AppButtonStyles.dangerFilled(context),
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.pop(context, _password.text);
          },
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}
