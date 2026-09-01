import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:bbm_sehat/config/api_config.dart';
import 'package:bbm_sehat/main.dart';
import 'package:bbm_sehat/services/activity_service.dart';
import 'package:bbm_sehat/services/auth_service.dart';
import 'package:bbm_sehat/services/leaderboard_service.dart';
import 'package:bbm_sehat/services/points_service.dart';
import 'package:bbm_sehat/services/token_storage.dart';
import 'package:bbm_sehat/state/activity_state.dart';
import 'package:bbm_sehat/state/app_state.dart';
import 'package:bbm_sehat/state/leaderboard_state.dart';
import 'package:bbm_sehat/state/points_state.dart';

import 'test_credentials.dart';

/// Drives the real login flow (Flutter UI -> AppState -> AuthService -> Dio
/// -> Laravel) against the actual backend running at ApiConfig.baseUrl.
/// Requires `php artisan serve` running with the 45-employee roster
/// imported, and the seeded super admin account (User ID BBM-0001) still at
/// its current password (see bbm-sehat-backend's EmployeeSeeder / earlier
/// reset). Login now uses the employee's User ID (employee_code), not email
/// — see Fase D of the auth migration.
///
/// Two test-environment quirks this file works around (see comments below):
/// flutter_secure_storage has no platform channel under `flutter test`, and
/// real async I/O (real sockets, real font downloads) must run inside
/// `tester.runAsync` or it hangs forever — a normal `pump()`'s fake-async
/// zone never resolves it.
class _InMemoryTokenStorage implements TokenStorage {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

/// Resets Farhan's password via the real admin API so this test is
/// re-runnable — the login flow itself permanently advances his
/// must_change_password state in the real database, so a hardcoded
/// temporary password would only ever work on the very first run.
Future<String> _resetFarhanPassword() async {
  final admin = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  final loginResponse = await admin.post('/login', data: {
    'employee_code': 'BBM-0001',
    'password': TestCredentials.adminPassword,
  });
  final adminToken = loginResponse.data['token'] as String;

  final employeesResponse = await admin.get(
    '/admin/employees',
    queryParameters: {'division_id': 4}, // IT — Farhan's division
    options: Options(headers: {'Authorization': 'Bearer $adminToken'}),
  );
  final farhan = (employeesResponse.data['data'] as List)
      .firstWhere((e) => e['employee_code'] == 'BBM-005');

  final resetResponse = await admin.post(
    '/admin/employees/${farhan['id']}/reset-password',
    options: Options(headers: {'Authorization': 'Bearer $adminToken'}),
  );

  return resetResponse.data['temporary_password'] as String;
}

void main() {
  setUpAll(() async {
    // Must be cleared before the font pre-warm below too — setUpAll runs
    // before any testWidgets body, and the binding's fake HTTP-as-400
    // override is already active by then.
    HttpOverrides.global = null;

    await initializeDateFormatting('id_ID');
    AuthService.debugOverrideStorage(_InMemoryTokenStorage());

    // dart:io pools idle connections for 15s by default — harmless in the
    // real app, but flutter_test's teardown asserts no timers are left
    // pending, which that pooled-connection timer otherwise trips.
    void disableConnectionPooling(Dio dio) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        return HttpClient()..idleTimeout = Duration.zero;
      };
    }

    AuthService.debugConfigureDio(disableConnectionPooling);
    ActivityService.debugConfigureDio(disableConnectionPooling);
    PointsService.debugConfigureDio(disableConnectionPooling);
    LeaderboardService.debugConfigureDio(disableConnectionPooling);

    // Pre-warm every font+weight the app uses, for real, exactly once for
    // the whole file. setUpAll isn't wrapped in a testWidgets fake-async
    // zone, so a plain await is safe here without needing runAsync.
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('gfonts_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => tempDir.path);
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600);
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700);
    GoogleFonts.lora(fontWeight: FontWeight.w400);
    GoogleFonts.lora(fontWeight: FontWeight.w700);
    await GoogleFonts.pendingFonts();
  });

  testWidgets('real login -> mandatory change-password -> Beranda, then re-login flows',
      (tester) async {
    HttpOverrides.global = null;

    final temporaryPassword = await tester.runAsync(_resetFarhanPassword);

    await tester.pumpWidget(const BbmSehatApp());
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    AppState state() => Provider.of<AppState>(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        );
    ActivityState activityState() => Provider.of<ActivityState>(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        );
    PointsState pointsState() => Provider.of<PointsState>(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        );
    LeaderboardState leaderboardState() => Provider.of<LeaderboardState>(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        );

    // A successful login that lands straight on Beranda (no change-password
    // detour) also triggers BerandaScreen's initState -> ActivityState,
    // PointsState, and LeaderboardState fetches via postFrameCallback —
    // same zone constraint as everywhere else in this suite: the login
    // call, the settling pump, and the wait for every fetch all have to
    // share one runAsync, or they're bound to the fake zone and never
    // resolve. Waiting on isLoading is a no-op (0 attempts) for calls that
    // land on Login or Change Password instead, since BerandaScreen never
    // mounts to start those fetches.
    Future<void> login(String employeeCode, String password) async {
      await tester.runAsync(() async {
        await state().login(employeeCode, password);
        await tester.pump(const Duration(milliseconds: 400));
        var attempts = 0;
        while ((activityState().isLoading || pointsState().isLoading || leaderboardState().isLoadingMyPosition) &&
            attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      });
      await tester.pumpAndSettle();
    }

    // 1) Fresh boot -> no stored session -> Login screen.
    expect(find.text('Masuk ke BBM Sehat'), findsOneWidget);

    // 2) Login with Farhan's freshly-reset temporary password.
    await login('BBM-005', temporaryPassword!);
    expect(find.text('Buat Password Baru'), findsOneWidget,
        reason: 'must_change_password should route here');

    // 3) Set a new password -> lands on Beranda, same fetch-zone constraint
    // as login() above.
    final newPassword = TestCredentials.farhanPassword;
    await tester.runAsync(() async {
      await state().submitNewPassword(newPassword);
      await tester.pump(const Duration(milliseconds: 400));
      var attempts = 0;
      while ((activityState().isLoading || pointsState().isLoading || leaderboardState().isLoadingMyPosition) &&
          attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget,
        reason: 'should land on Beranda after password change');

    // 4) Logout back to Login.
    await tester.runAsync(() => state().logout());
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke BBM Sehat'), findsOneWidget);

    // 5) Old (temporary) password must now be rejected — no crash, no
    // navigation away from Login.
    await login('BBM-005', temporaryPassword);
    expect(find.text('Masuk ke BBM Sehat'), findsOneWidget, reason: 'stays on Login after 401');
    expect(find.textContaining('salah'), findsOneWidget);

    // 6) New password logs straight into Beranda (must_change_password now
    // false — no change-password screen this time).
    await login('BBM-005', newPassword);
    expect(find.text('Buat Password Baru'), findsNothing);
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget);

    // 7) Logout again before the rate-limit probe.
    await tester.runAsync(() => state().logout());
    await tester.pumpAndSettle();

    // 8) 6 failed attempts on a throwaway identifier -> 429 on the 6th.
    for (var i = 1; i <= 6; i++) {
      await login('RATE-LIMIT-PROBE', 'wrong-password');
    }
    expect(find.textContaining('Terlalu banyak percobaan'), findsOneWidget);

    // 9) Nonexistent account -> clear error, no crash, still on Login.
    await login('BBM-9999', 'whatever123');
    expect(find.text('Masuk ke BBM Sehat'), findsOneWidget);
  });
}
