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
import 'package:bbm_sehat/state/employee_state.dart';
import 'package:bbm_sehat/state/leaderboard_state.dart';
import 'package:bbm_sehat/state/points_state.dart';

import 'test_credentials.dart';

/// Drives the real Profil flow against the live backend: two already
/// past-first-login accounts (Farhan / Super Admin — see
/// login_backend_integration_test.dart for how they got there), so this
/// file only exercises GET /api/me + POST /api/logout, not password change.
class _InMemoryTokenStorage implements TokenStorage {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('id_ID');
    AuthService.debugOverrideStorage(_InMemoryTokenStorage());

    // dart:io's HttpClient pools idle connections for 15s by default —
    // fine in the real app, but flutter_test's teardown asserts no timers
    // are left pending, and that pooled-connection timer legitimately
    // outlives a fast-finishing test. Disabling pooling avoids it.
    void disableConnectionPooling(Dio dio) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        return HttpClient()..idleTimeout = Duration.zero;
      };
    }

    AuthService.debugConfigureDio(disableConnectionPooling);
    ActivityService.debugConfigureDio(disableConnectionPooling);
    PointsService.debugConfigureDio(disableConnectionPooling);
    LeaderboardService.debugConfigureDio(disableConnectionPooling);

    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('gfonts_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => tempDir.path);
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600);
    GoogleFonts.lora(fontWeight: FontWeight.w400);
    await GoogleFonts.pendingFonts();
  });

  testWidgets('Profil shows real employee data, differs per account, and logout revokes the token',
      (tester) async {
    HttpOverrides.global = null;

    await tester.pumpWidget(const BbmSehatApp());
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    BuildContext ctx() => tester.element(find.byType(MaterialApp));
    AppState appState() => Provider.of<AppState>(ctx(), listen: false);
    EmployeeState employeeState() => Provider.of<EmployeeState>(ctx(), listen: false);
    ActivityState activityState() => Provider.of<ActivityState>(ctx(), listen: false);
    PointsState pointsState() => Provider.of<PointsState>(ctx(), listen: false);
    LeaderboardState leaderboardState() => Provider.of<LeaderboardState>(ctx(), listen: false);

    // The postFrameCallback that starts Profil's fetchMe() + PointsState's
    // fetchSummary() captures whatever zone is active when it's *scheduled*
    // (during the tap), not when it fires later — so the tap, the settling
    // pump, and the wait for both fetches to resolve all have to happen
    // inside one runAsync call, or their Futures are bound to the fake test
    // zone and never resolve. (Profil doesn't touch LeaderboardState.)
    Future<void> goToProfilAndWait() async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Profil'));
        await tester.pump(const Duration(milliseconds: 400));
        var attempts = 0;
        while ((employeeState().isLoading || pointsState().isLoading) && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      });
      await tester.pump();
    }

    // Login lands directly on Beranda, whose initState fires
    // ActivityState's, PointsState's, and LeaderboardState's own fetches
    // via postFrameCallback — same zone constraint as above, so the login
    // call, settling pump, and wait for every fetch all share one runAsync
    // too.
    Future<void> loginAndWaitForBeranda(String identifier, String password) async {
      await tester.runAsync(() async {
        await appState().login(identifier, password);
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

    // 1) Login as Farhan, open Profil -> real data, not "Andi Pratama".
    await loginAndWaitForBeranda('BBM-005', TestCredentials.farhanPassword);
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget);

    await goToProfilAndWait();
    expect(employeeState().employee?.fullName, 'Farhan');
    // findsWidgets, not findsOneWidget: Beranda's greeting reads the same
    // EmployeeState now, so "Farhan" can legitimately appear there too
    // (plus possibly mid cross-fade alongside Profil's copy).
    expect(find.text('Farhan'), findsWidgets);
    expect(find.text('IT · ID BBM-005'), findsOneWidget);

    // 2) Capture the token, then logout -> Login screen.
    final farhanToken = await AuthService.instance.readToken();
    expect(farhanToken, isNotNull);

    // Mirrors ProfilScreen's actual "Keluar" handler (clear employee data,
    // then log out) — the real app's only reachable logout path already
    // does both together.
    employeeState().clear();
    activityState().clear();
    pointsState().clear();
    leaderboardState().clear();
    await tester.runAsync(() => appState().logout());
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke BBM Sehat'), findsOneWidget);

    // 3) The old token must be dead server-side, not just forgotten locally.
    await tester.runAsync(() async {
      final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      try {
        await probe.get('/me', options: Options(headers: {'Authorization': 'Bearer $farhanToken'}));
        fail('expected the revoked token to be rejected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
      }
    });

    // 4) A different account shows different data, not Farhan's cached copy.
    await loginAndWaitForBeranda('BBM-0001', TestCredentials.adminPassword);
    await goToProfilAndWait();
    expect(employeeState().employee?.fullName, 'Super Admin');
    expect(find.text('Super Admin'), findsWidgets);
    expect(find.text('IT · ID BBM-0001'), findsOneWidget);

    // 5) "Reopen the app" without logging out: a fresh widget tree with the
    // same stored token should skip Login and land straight in the app,
    // with Profil still resolving to the right employee. Same zone
    // constraint as goToProfilAndWait — the boot Timer's session check
    // makes a real call, so triggering it and waiting for it both need to
    // happen inside runAsync.
    // pumpWidget() with an equal widget (same const BbmSehatApp) reuses the
    // existing element tree/State instead of tearing it down — a real "kill
    // and reopen the app" needs the old tree actually disposed first, so
    // AppState's constructor (and its boot-time session check) genuinely
    // reruns instead of reusing the already-logged-in instance.
    await tester.pumpWidget(Container());
    await tester.runAsync(() async {
      await tester.pumpWidget(const BbmSehatApp());
      await tester.pump(const Duration(milliseconds: 1800));
      var attempts = 0;
      while (appState().flow == AppFlow.splash && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      // The flow flag flipping away from splash doesn't by itself rebuild
      // the widget tree (that needs an actual pump) — and that pump is what
      // mounts BerandaScreen and schedules its ActivityState fetch, so it
      // has to happen inside this same real zone too, or the fetch is bound
      // to the fake zone that pumpAndSettle() below would otherwise use.
      await tester.pump(const Duration(milliseconds: 400));
      attempts = 0;
      while ((activityState().isLoading || pointsState().isLoading || leaderboardState().isLoadingMyPosition) &&
          attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget, reason: 'valid session should skip Login on relaunch');

    await goToProfilAndWait();
    expect(employeeState().employee?.fullName, 'Super Admin');
    expect(find.text('Super Admin'), findsWidgets);

    // dart:io schedules a 15s idle-connection-pool timer as a *fake* Timer
    // (created inside the test's FakeAsync zone, per its own stack trace) —
    // so it's bound to the fake clock, not real time; a real-time wait
    // inside runAsync never touches it. Advancing the fake clock directly
    // does.
    await tester.pump(const Duration(seconds: 16));
  });
}
