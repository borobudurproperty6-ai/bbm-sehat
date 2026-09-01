import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

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

/// Drives the real Beranda greeting against the live backend — no Profil
/// visit involved, since the point is that AppShell fetches on its own.
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

    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('gfonts_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => tempDir.path);
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600);
    GoogleFonts.lora(fontWeight: FontWeight.w400);
    await GoogleFonts.pendingFonts();
  });

  testWidgets('Beranda greets with the real logged-in employee, without ever visiting Profil',
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

    // AppShell's initState fires EmployeeState.fetchIfNeeded() and
    // BerandaScreen's initState fires ActivityState.fetchToday(),
    // PointsState.fetchSummary(), and LeaderboardState.fetchMyPosition(),
    // all via postFrameCallback, the moment login lands on Beranda — those
    // callbacks capture whatever zone is active when they're *scheduled*
    // (during login), not when they fire, so the login call and the wait
    // for every fetch to resolve all have to happen inside one runAsync.
    Future<void> loginAndWaitForEmployee(String identifier, String password) async {
      await tester.runAsync(() async {
        await appState().login(identifier, password);
        // Mounts AppShell + BerandaScreen (within this same real zone) so
        // their postFrameCallbacks — which start the fetches — are
        // captured here too, not in the fake zone a bare pumpAndSettle()
        // would use.
        await tester.pump(const Duration(milliseconds: 400));
        var attempts = 0;
        while ((employeeState().employee == null ||
                activityState().isLoading ||
                pointsState().isLoading ||
                leaderboardState().isLoadingMyPosition) &&
            attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      });
      await tester.pumpAndSettle();
    }

    // 1) Login as Farhan, land on Beranda directly — never tap Profil.
    await loginAndWaitForEmployee('BBM-005', TestCredentials.farhanPassword);
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget);
    expect(employeeState().employee?.fullName, 'Farhan');
    expect(find.text('Farhan'), findsOneWidget);
    expect(find.text('IT'), findsOneWidget);
    expect(find.text('Andi Pratama'), findsNothing, reason: 'greeting must not still be mock');

    // The km/kcal stat tile and weekly strip stay mock, untouched by this
    // session's work — steps (verified in activity_backend_integration_test)
    // and points (verified in points_backend_integration_test) are both real.
    expect(find.text('km hari ini'), findsOneWidget, reason: 'mock stat tile unchanged');
    expect(find.text('poin hari ini'), findsOneWidget, reason: 'label unchanged, value now real');

    // 2) Beranda and Profil agree for the same account.
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
    // findsWidgets, not findsOneWidget: AnimatedSwitcher can still have
    // Beranda's greeting mounted (mid cross-fade) alongside Profil's own
    // "Farhan" text at this exact point — both showing the same real name
    // is exactly the consistency this step is checking.
    expect(find.text('Farhan'), findsWidgets);

    // Mirrors ProfilScreen's actual "Keluar" handler (clear employee +
    // activity data, then log out) — the real app's only reachable logout
    // path already does this; calling AppState.logout() alone here would
    // test a shortcut no real user can take.
    employeeState().clear();
    activityState().clear();
    pointsState().clear();
    leaderboardState().clear();
    await tester.runAsync(() => appState().logout());
    await tester.pumpAndSettle();

    // 3) A different account shows a different greeting, not Farhan's.
    await loginAndWaitForEmployee('BBM-0001', TestCredentials.adminPassword);
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget);
    expect(employeeState().employee?.fullName, 'Super Admin');
    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('Farhan'), findsNothing, reason: 'must not show the previous account\'s name');

    // dart:io's idle-connection-pool timer is a *fake* Timer in this test
    // zone (bound to the fake clock, not real time) — advance it past its
    // 15s expiry so flutter_test's teardown doesn't trip on it.
    await tester.pump(const Duration(seconds: 16));
  });
}
