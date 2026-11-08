import 'package:agrovet/core/theme.dart';
import 'package:agrovet/data/remote/api_client.dart';
import 'package:agrovet/data/remote/auth_api.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:agrovet/domain/session.dart';
import 'package:agrovet/presentation/auth/auth_cubit.dart';
import 'package:agrovet/presentation/auth/forgot_password_screen.dart';
import 'package:agrovet/presentation/auth/login_screen.dart';
import 'package:agrovet/presentation/auth/password_reset_cubit.dart';
import 'package:agrovet/presentation/auth/verify_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthApi extends Mock implements AuthApi {}

const _session = Session(
  userId: 'u1',
  name: 'Ana',
  email: 'ana@correo.co',
  accessToken: 'a',
  refreshToken: 'r',
);

const _notVerified = ApiException(
  'Debe verificar su correo antes de ingresar.',
  statusCode: 403,
  code: ApiException.emailNotVerified,
);

Widget _app(AuthCubit cubit, Widget child) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      ),
    );

void main() {
  late _MockAuthApi api;
  late SecureStore store;
  final now = DateTime(2026, 11, 8, 10);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = SecureStore();
    api = _MockAuthApi();
  });

  AuthCubit cubit() => AuthCubit(store: store, api: api, allowDemo: false, clock: () => now);

  group('AuthCubit', () {
    test('registrarse lleva a escribir el código, con espera de 60 s para reenviar', () async {
      when(() => api.register('Ana', 'ana@correo.co', 'clave-segura-1')).thenAnswer((_) async {});
      final auth = cubit();
      await auth.register('Ana', 'ana@correo.co', 'clave-segura-1');

      final state = auth.state as AwaitingVerification;
      expect(state.email, 'ana@correo.co');
      expect(state.resendAvailableAt, now.add(const Duration(seconds: 60)));
      expect(await store.readSession(), isNull);
    });

    test('ingresar sin verificar lleva a la pantalla del código', () async {
      when(() => api.login(any(), any())).thenThrow(_notVerified);
      final auth = cubit();
      await auth.login(' ana@correo.co ', 'clave-segura-1');

      final state = auth.state as AwaitingVerification;
      expect(state.email, 'ana@correo.co');
      expect(state.info, _notVerified.message);
      expect(state.resendAvailableAt, now);
    });

    test('el código correcto abre la sesión y la guarda para usarla sin conexión', () async {
      when(() => api.register(any(), any(), any())).thenAnswer((_) async {});
      when(() => api.verifyEmail('ana@correo.co', '123456')).thenAnswer((_) async => _session);
      final auth = cubit();
      await auth.register('Ana', 'ana@correo.co', 'clave-segura-1');
      await auth.verify('123456');

      expect(auth.state, const Authenticated(_session));
      expect(await store.readSession(), _session);
    });

    test('un código incorrecto deja el mensaje y sigue esperando', () async {
      when(() => api.register(any(), any(), any())).thenAnswer((_) async {});
      when(() => api.verifyEmail(any(), any()))
          .thenThrow(const ApiException('El código no es válido o ya venció.', statusCode: 400));
      final auth = cubit();
      await auth.register('Ana', 'ana@correo.co', 'clave-segura-1');
      await auth.verify('000000');

      final state = auth.state as AwaitingVerification;
      expect(state.message, 'El código no es válido o ya venció.');
      expect(state.busy, isFalse);
    });

    test('reenviar respeta la espera y usa el Retry-After del servidor', () async {
      when(() => api.login(any(), any())).thenThrow(_notVerified);
      when(() => api.resendCode('ana@correo.co'))
          .thenThrow(const ApiException('Espere.', statusCode: 429, retryAfter: Duration(seconds: 42)));
      final auth = cubit();
      await auth.login('ana@correo.co', 'clave-segura-1');
      await auth.resendCode();

      final state = auth.state as AwaitingVerification;
      expect(state.resendAvailableAt, now.add(const Duration(seconds: 42)));
      expect(state.message, 'Espere.');
    });

    test('no reenvía antes de tiempo', () async {
      when(() => api.register(any(), any(), any())).thenAnswer((_) async {});
      final auth = cubit();
      await auth.register('Ana', 'ana@correo.co', 'clave-segura-1');
      await auth.resendCode();
      verifyNever(() => api.resendCode(any()));
    });

    test('sin internet el registro muestra el error y no avanza', () async {
      when(() => api.register(any(), any(), any())).thenThrow(
          const ApiException('No hay conexión con el servidor. Revise su internet e intente de nuevo.'));
      final auth = cubit();
      await auth.register('Ana', 'ana@correo.co', 'clave-segura-1');
      expect(auth.state, isA<Unauthenticated>());
      expect((auth.state as Unauthenticated).message, contains('No hay conexión'));
    });

    test('la sesión guardada abre la app sin conexión', () async {
      await store.saveSession(_session);
      final auth = cubit();
      await auth.restore();
      expect(auth.state, const Authenticated(_session));
      verifyZeroInteractions(api);
    });
  });

  group('PasswordResetCubit', () {
    test('pide el código, cambia la contraseña e inicia sesión con la nueva', () async {
      when(() => api.forgotPassword('ana@correo.co')).thenAnswer((_) async {});
      when(() => api.resetPassword('ana@correo.co', '654321', 'nueva-clave-22')).thenAnswer((_) async {});
      when(() => api.login('ana@correo.co', 'nueva-clave-22')).thenAnswer((_) async => _session);
      final reset = PasswordResetCubit(api, clock: () => now);

      await reset.requestCode('ana@correo.co');
      expect(reset.state.step, PasswordResetStep.code);
      expect(reset.state.resendAvailableAt, now.add(const Duration(seconds: 60)));

      await reset.reset('654321', 'nueva-clave-22');
      expect(reset.state.step, PasswordResetStep.done);
      expect(reset.state.session, _session);
    });

    test('un código inválido muestra el error sin avanzar', () async {
      when(() => api.forgotPassword(any())).thenAnswer((_) async {});
      when(() => api.resetPassword(any(), any(), any()))
          .thenThrow(const ApiException('El código no es válido o ya venció.', statusCode: 400));
      final reset = PasswordResetCubit(api, clock: () => now);
      await reset.requestCode('ana@correo.co');
      await reset.reset('000000', 'nueva-clave-22');
      expect(reset.state.step, PasswordResetStep.code);
      expect(reset.state.message, contains('no es válido'));
      verifyNever(() => api.login(any(), any()));
    });
  });

  group('pantallas', () {
    testWidgets('la pantalla del código muestra el correo, la cuenta regresiva y verifica al completar',
        (tester) async {
      when(() => api.register(any(), any(), any())).thenAnswer((_) async {});
      when(() => api.verifyEmail('ana@correo.co', '123456')).thenAnswer((_) async => _session);
      final auth = AuthCubit(store: store, api: api, allowDemo: false);
      await auth.register('Ana', 'ana@correo.co', 'clave-segura-1');

      await tester.pumpWidget(_app(auth, const VerifyEmailScreen()));
      await tester.pump();
      expect(find.textContaining('ana@correo.co'), findsWidgets);
      // Cuenta regresiva activa (0:5x o 1:00 según cuánto tarde la prueba) y botón deshabilitado
      expect(find.textContaining(RegExp(r'Reenviar código en (1:00|0:5\d)')), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Código'), '123456');
      await tester.pump();
      expect(auth.state, const Authenticated(_session));
    });

    testWidgets('el código solo acepta números', (tester) async {
      when(() => api.login(any(), any())).thenThrow(_notVerified);
      final auth = AuthCubit(store: store, api: api, allowDemo: false);
      await auth.login('ana@correo.co', 'clave-segura-1');

      await tester.pumpWidget(_app(auth, const VerifyEmailScreen()));
      await tester.pump();
      expect(find.text('Reenviar código'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Código'), '12ab');
      await tester.tap(find.text('Verificar'));
      await tester.pump();
      expect(find.text('Escriba los 6 números del código'), findsOneWidget);
      verifyNever(() => api.verifyEmail(any(), any()));
    });

    testWidgets('el ingreso ofrece recuperar la contraseña', (tester) async {
      when(() => api.forgotPassword('ana@correo.co')).thenAnswer((_) async {});
      final auth = AuthCubit(store: store, api: api, allowDemo: false)..emit(const Unauthenticated());
      await tester.pumpWidget(_app(auth, const LoginScreen()));
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'ana@correo.co');
      await tester.tap(find.text('Olvidé mi contraseña'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Escriba el código que llegó a ana@correo.co'), findsOneWidget);
      expect(find.text('Contraseña nueva'), findsOneWidget);
    });

    testWidgets('al registrarse avisa que necesita internet', (tester) async {
      final auth = AuthCubit(store: store, api: api, allowDemo: false)..emit(const Unauthenticated());
      await tester.pumpWidget(_app(auth, const LoginScreen()));
      await tester.tap(find.text('No tengo cuenta: crear una'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Necesita internet para crear la cuenta'), findsOneWidget);
      expect(find.text('Olvidé mi contraseña'), findsNothing);
    });
  });
}
