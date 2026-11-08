import 'package:agrovet/core/theme.dart';
import 'package:agrovet/data/local/local_data_wiper.dart';
import 'package:agrovet/data/remote/api_client.dart';
import 'package:agrovet/data/remote/auth_api.dart';
import 'package:agrovet/data/remote/profile_api.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:agrovet/domain/privacy_notice.dart';
import 'package:agrovet/domain/session.dart';
import 'package:agrovet/presentation/auth/auth_cubit.dart';
import 'package:agrovet/presentation/auth/login_screen.dart';
import 'package:agrovet/presentation/profile/profile_cubit.dart';
import 'package:agrovet/presentation/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockProfileApi extends Mock implements ProfileApi {}

const _session = Session(
  userId: 'u1',
  name: 'Ana',
  email: 'ana@correo.co',
  accessToken: 'a1',
  refreshToken: 'r1',
  privacyPolicyVersion: PrivacyNotice.version,
);

void main() {
  late _MockAuthApi authApi;
  late _MockProfileApi profileApi;
  late SecureStore store;
  late AuthCubit auth;
  late List<String> events;
  late LocalDataWiper wiper;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    store = SecureStore();
    authApi = _MockAuthApi();
    profileApi = _MockProfileApi();
    events = [];
    wiper = LocalDataWiper(() async => events.add('wipe'));
    auth = AuthCubit(store: store, api: authApi, allowDemo: true);
    await auth.openSession(_session);
  });

  ProfileCubit cubit() => ProfileCubit(api: profileApi, auth: auth, wiper: wiper);

  Widget app(Widget child) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ProfileApi>.value(value: profileApi),
          RepositoryProvider<LocalDataWiper>.value(value: wiper),
        ],
        child: BlocProvider.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: child,
          ),
        ),
      );

  group('ProfileCubit', () {
    test('guardar actualiza el perfil y la copia local sin perder los tokens', () async {
      when(() => profileApi.update(
            name: 'Ana María',
            farmName: 'La Esperanza',
            municipality: 'Pasto',
            phone: '',
          )).thenAnswer((_) async => const Session(
            userId: 'u1',
            name: 'Ana María',
            email: 'ana@correo.co',
            farmName: 'La Esperanza',
            municipality: 'Pasto',
            privacyPolicyVersion: PrivacyNotice.version,
          ));
      final ok = await cubit().save(name: 'Ana María', farmName: 'La Esperanza', municipality: 'Pasto', phone: '');

      expect(ok, isTrue);
      final saved = await store.readSession();
      expect(saved!.name, 'Ana María');
      expect(saved.farmName, 'La Esperanza');
      expect(saved.accessToken, 'a1');
      expect(saved.refreshToken, 'r1');
    });

    test('sin internet el perfil guardado se sigue viendo', () async {
      when(() => profileApi.fetch()).thenThrow(const ApiException('No hay conexión con el servidor.'));
      final profile = cubit();
      await profile.refresh();
      expect((auth.state as Authenticated).session, _session);
      expect(profile.state.error, isNull);
    });

    test('cambiar la contraseña guarda los tokens nuevos', () async {
      when(() => profileApi.changePassword('vieja-clave', 'nueva-clave-22')).thenAnswer((_) async =>
          const Session(userId: 'u1', name: 'Ana', email: 'ana@correo.co', accessToken: 'a2', refreshToken: 'r2'));
      expect(await cubit().changePassword('vieja-clave', 'nueva-clave-22'), isTrue);
      final saved = await store.readSession();
      expect(saved!.accessToken, 'a2');
      expect(saved.refreshToken, 'r2');
      expect(saved.privacyPolicyVersion, PrivacyNotice.version);
    });

    test('eliminar la cuenta sale de la sesión y borra los datos del celular', () async {
      when(() => profileApi.deleteAccount('clave-segura-1')).thenAnswer((_) async {
        events.add('servidor');
      });
      expect(await cubit().deleteAccount('clave-segura-1'), isTrue);

      expect(events, ['servidor', 'wipe']);
      expect(auth.state, isA<Unauthenticated>());
      expect((auth.state as Unauthenticated).message, contains('eliminados'));
      expect(await store.readSession(), isNull);
    });

    test('con la contraseña equivocada no se borra nada', () async {
      when(() => profileApi.deleteAccount(any()))
          .thenThrow(const ApiException('La contraseña no es correcta.', statusCode: 401));
      final profile = cubit();
      expect(await profile.deleteAccount('equivocada'), isFalse);
      expect(profile.state.error, 'La contraseña no es correcta.');
      expect(events, isEmpty);
      expect(auth.state, isA<Authenticated>());
    });

    test('la sesión de demostración no toca el servidor', () async {
      auth.enterDemo();
      final profile = cubit();
      expect(await profile.save(name: 'X'), isFalse);
      expect(profile.state.error, contains('demostración'));
      verifyZeroInteractions(profileApi);
    });
  });

  group('pantallas', () {
    testWidgets('el registro exige aceptar el aviso de privacidad', (tester) async {
      final login = AuthCubit(store: store, api: authApi, allowDemo: false)..emit(const Unauthenticated());
      await tester.pumpWidget(BlocProvider.value(value: login, child: app(const LoginScreen())));
      await tester.tap(find.text('No tengo cuenta: crear una'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana');
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'ana@correo.co');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave-segura-1');

      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(find.text('Debe aceptar el aviso de privacidad para crear la cuenta'), findsOneWidget);
      verifyNever(() => authApi.register(any(), any(), any(), acceptedPrivacy: any(named: 'acceptedPrivacy')));

      when(() => authApi.register('Ana', 'ana@correo.co', 'clave-segura-1', acceptedPrivacy: true))
          .thenAnswer((_) async {});
      await tester.scrollUntilVisible(find.byType(Checkbox), 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Crear cuenta'), 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      verify(() => authApi.register('Ana', 'ana@correo.co', 'clave-segura-1', acceptedPrivacy: true)).called(1);
    });

    testWidgets('el aviso de privacidad se puede leer desde el registro', (tester) async {
      final login = AuthCubit(store: store, api: authApi, allowDemo: false)..emit(const Unauthenticated());
      await tester.pumpWidget(BlocProvider.value(value: login, child: app(const LoginScreen())));
      await tester.tap(find.text('No tengo cuenta: crear una'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Leer el aviso de privacidad'));
      await tester.tap(find.text('Leer el aviso de privacidad'));
      await tester.pumpAndSettle();
      expect(find.text('Sus derechos'), findsOneWidget);
      expect(find.textContaining('Ley 1581 de 2012'), findsOneWidget);
    });

    testWidgets('el perfil muestra los datos guardados y pide la autorización si falta', (tester) async {
      when(() => profileApi.fetch()).thenThrow(const ApiException('Sin conexión'));
      await auth.updateSession(const Session(
        userId: 'u1',
        name: 'Ana',
        email: 'ana@correo.co',
        accessToken: 'a1',
        refreshToken: 'r1',
        municipality: 'Pasto',
      ));
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ana@correo.co'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Pasto'), findsOneWidget);
      expect(find.text('Falta su autorización'), findsOneWidget);
      expect(find.text('Eliminar mi cuenta'), findsOneWidget);
    });

    testWidgets('eliminar la cuenta pide la contraseña antes de borrar', (tester) async {
      when(() => profileApi.fetch()).thenAnswer((_) async => _session);
      when(() => profileApi.deleteAccount('clave-segura-1')).thenAnswer((_) async {});
      // Pantalla alta para que el perfil completo quepa sin desplazar
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar su cuenta?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pump();
      expect(find.text('Escriba su contraseña para confirmar'), findsOneWidget);
      verifyNever(() => profileApi.deleteAccount(any()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Su contraseña'), 'clave-segura-1');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      verify(() => profileApi.deleteAccount('clave-segura-1')).called(1);
      expect(events, ['wipe']);
      expect(auth.state, isA<Unauthenticated>());
    });
  });

  test('la sesión guarda y recupera el perfil para verlo sin conexión', () {
    const full = Session(
      userId: 'u1',
      name: 'Ana',
      email: 'ana@correo.co',
      accessToken: 'a',
      refreshToken: 'r',
      farmName: 'La Esperanza',
      municipality: 'Pasto',
      phone: '3001234567',
      privacyPolicyVersion: '2026-11',
    );
    expect(Session.fromJson(full.toJson()), full);
    // Sesiones guardadas por versiones anteriores de la app siguen sirviendo
    expect(Session.fromJson({'userId': 'u1', 'name': 'Ana', 'email': 'a@b.co'}).farmName, isNull);
  });

  test('olvidar al usuario borra su clave de base y su última sincronización', () async {
    await store.databaseKeyFor('u1');
    await store.saveLastSync('u1', DateTime(2026, 11, 8));
    await store.forgetUser('u1');
    expect(await store.lastSyncFor('u1'), isNull);
    // Una clave nueva confirma que la anterior ya no existe
    final key = await store.databaseKeyFor('u1');
    expect(key, hasLength(64));
  });
}
