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
import 'package:bbm_sehat/state/history_state.dart';
import 'package:bbm_sehat/state/leaderboard_state.dart';
import 'package:bbm_sehat/state/points_state.dart';

import 'test_credentials.dart';

class _InMemoryTokenStorage implements TokenStorage {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

final _fontsTempDir = Directory.systemTemp.createTempSync('gfonts_test_');
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

// Exercises every screen and the main interactions on a set of phone-sized
// viewports so layout overflows and null/exception bugs surface in CI
// without needing a real device or browser. The app now requires a real
// backend login to get past the gate — everything past that (Beranda,
// Riwayat, Jalan Kaki, Papan, Badge, Profil) is still mock data, unchanged.
// Uses a dedicated account (not the one login_backend_integration_test.dart
// exercises) since `flutter test` runs test files concurrently.
void main() {
  setUpAll(() async {
    // Must be cleared before the font pre-warm below too, not just inside
    // each testWidgets body — setUpAll runs first and the binding's fake
    // HttpOverrides is already active by then.
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

    // Pre-warm every font+weight the app uses exactly once for the whole
    // file (not once per size below — doing it repeatedly in each
    // testWidgets body was flaky: real network + mock-handler churn
    // compounding across iterations of the same isolate). setUpAll isn't
    // wrapped in a testWidgets fake-async zone, so a plain await is safe
    // here without needing runAsync.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async => _fontsTempDir.path);
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600);
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w700);
    GoogleFonts.lora(fontWeight: FontWeight.w400);
    GoogleFonts.lora(fontWeight: FontWeight.w700);
    await GoogleFonts.pendingFonts();
  });

  for (final size in [
    const Size(360, 780), // small Android
    const Size(390, 844), // iPhone 14
    const Size(430, 932), // iPhone 14 Pro Max
  ]) {
    testWidgets('full flow renders without errors at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // TestWidgetsFlutterBinding fakes HTTP as 400 by default and resets
      // mock channel handlers between tests — both need reasserting here.
      // Fonts themselves were already fetched once in setUpAll, so this is
      // just re-pointing the (cheap, local-disk-only) handler, not
      // triggering new network activity.
      HttpOverrides.global = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, (call) async => _fontsTempDir.path);

      await tester.pumpWidget(const BbmSehatApp());

      // Splash -> Login.
      await tester.pump(const Duration(milliseconds: 1800));
      expect(find.text('Masuk ke BBM Sehat'), findsOneWidget);

      // Login -> Beranda (dedicated account already past first-login
      // password change, so no change-password screen in between).
      final state = Provider.of<AppState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      final employeeState = Provider.of<EmployeeState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      final activityState = Provider.of<ActivityState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      final pointsState = Provider.of<PointsState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      final leaderboardState = Provider.of<LeaderboardState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      final historyState = Provider.of<HistoryState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      // Profil's initState fetches GET /api/me + points summary via a
      // postFrameCallback, which captures whatever zone is active when it's
      // *scheduled* (the tap), not when it fires — so the tap, the settling
      // pump, and the wait for both fetches to resolve all have to happen
      // inside one runAsync call, or their Futures never resolve.
      Future<void> goToProfilAndWait() async {
        await tester.runAsync(() async {
          await tester.tap(find.text('Profil'));
          await tester.pump(const Duration(milliseconds: 400));
          var attempts = 0;
          while ((employeeState.isLoading || pointsState.isLoading) && attempts < 50) {
            await Future.delayed(const Duration(milliseconds: 100));
            attempts++;
          }
        });
        await tester.pump();
      }

      // Same zone constraint applies to BerandaScreen's ActivityState,
      // PointsState, and LeaderboardState fetches, which land the moment
      // login lands on Beranda — the login call, the settling pump, and
      // the wait for every fetch must share one runAsync, or their Futures
      // are bound to the fake zone and never resolve.
      await tester.runAsync(() async {
        await state.login('BBM-0001', TestCredentials.adminPassword);
        await tester.pump(const Duration(milliseconds: 400));
        var attempts = 0;
        while ((employeeState.employee == null ||
                activityState.isLoading ||
                pointsState.isLoading ||
                leaderboardState.isLoadingMyPosition) &&
            attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Mulai Jalan Kaki'), findsOneWidget);

      // Beranda -> Riwayat, toggle range. RiwayatScreen's initState fires a
      // HistoryState.fetch() the moment it mounts, and each Mingguan/Bulanan
      // tap fires another one — same zone constraint as every other real
      // fetch in this suite: the triggering tap, settling pump, and wait
      // for it to resolve all have to share one runAsync.
      Future<void> tapAndWaitForHistory(String label) async {
        await tester.runAsync(() async {
          await tester.tap(find.text(label));
          await tester.pump(const Duration(milliseconds: 400));
          var attempts = 0;
          while (historyState.isLoading && attempts < 50) {
            await Future.delayed(const Duration(milliseconds: 100));
            attempts++;
          }
        });
        await tester.pumpAndSettle();
      }

      await tapAndWaitForHistory('Riwayat');
      expect(find.text('Riwayat Aktivitas'), findsOneWidget);
      await tapAndWaitForHistory('Bulanan');
      await tapAndWaitForHistory('Mingguan');

      // -> Papan Peringkat, cycle tabs. PapanPeringkatScreen's initState
      // fires a LeaderboardState.fetchEntries() the moment it mounts, and
      // each tab tap fires another one — same zone constraint as every
      // other real fetch in this suite: the triggering tap, settling pump,
      // and wait for it to resolve all have to share one runAsync.
      Future<void> tapAndWaitForLeaderboard(String label) async {
        await tester.runAsync(() async {
          await tester.tap(find.text(label));
          await tester.pump(const Duration(milliseconds: 400));
          var attempts = 0;
          while (leaderboardState.isLoadingEntries && attempts < 50) {
            await Future.delayed(const Duration(milliseconds: 100));
            attempts++;
          }
        });
        await tester.pumpAndSettle();
      }

      await tapAndWaitForLeaderboard('Peringkat');
      expect(find.text('Papan Peringkat'), findsOneWidget);
      await tapAndWaitForLeaderboard('Semua Divisi');
      await tapAndWaitForLeaderboard('Perusahaan');
      await tapAndWaitForLeaderboard('Divisi');

      // -> Profil (now real data, not mock "Andi Pratama") -> Badges ->
      // open one badge -> close.
      await goToProfilAndWait();
      expect(employeeState.employee?.fullName, 'Super Admin');
      // findsWidgets, not findsOneWidget: Super Admin now has real
      // leaderboard points, so Papan Peringkat's board (still mid
      // cross-fade out) can legitimately still show "Super Admin" at the
      // same instant Profil's own copy renders.
      expect(find.text('Super Admin'), findsWidgets);
      await tester.tap(find.text('Pencapaian & Lencana'));
      await tester.pumpAndSettle();
      expect(find.text('Pencapaian'), findsOneWidget);
      await tester.tap(find.text('Langkah Pertama'));
      await tester.pumpAndSettle();
      expect(find.text('Tutup'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      // Back to Beranda, then start a walk end-to-end. Re-entering Beranda
      // rebuilds it (AnimatedSwitcher tears down the old instance), so its
      // initState fires fresh ActivityState, PointsState, and
      // LeaderboardState fetches — same zone constraint as
      // goToProfilAndWait, or they're left dangling in the fake zone for
      // the rest of the test.
      await tester.runAsync(() async {
        await tester.tap(find.text('Beranda'));
        await tester.pump(const Duration(milliseconds: 400));
        var attempts = 0;
        while ((activityState.isLoading || pointsState.isLoading || leaderboardState.isLoadingMyPosition) &&
            attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      });
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mulai Jalan Kaki'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mulai Jalan Kaki'));
      await tester.pumpAndSettle();
      expect(find.text('Siap jalan kaki?'), findsOneWidget);
      // Real GPS tracking (geolocator + the walk-sessions backend) starts
      // here on a "Mulai Rekam" tap — that's genuinely native functionality
      // with no platform channel under `flutter_test`'s VM, so it's
      // verified for real on the Android emulator instead (see
      // walk_sessions_backend_integration_test.dart for the backend half).
      // This just confirms the idle screen itself renders correctly, then
      // heads back — same fetch-on-mount zone constraint as every other
      // Beranda re-entry in this suite.
      await tester.runAsync(() async {
        await tester.tap(find.text('Beranda'));
        await tester.pump(const Duration(milliseconds: 400));
        var attempts = 0;
        while ((activityState.isLoading || pointsState.isLoading || leaderboardState.isLoadingMyPosition) &&
            attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Mulai Jalan Kaki'), findsOneWidget);

      // Logout back to login — logout() now makes a real backend call, so
      // it needs runAsync same as login() above (a plain tap() would hang).
      await goToProfilAndWait();
      await tester.runAsync(() => state.logout());
      await tester.pumpAndSettle();
      expect(find.text('Masuk ke BBM Sehat'), findsOneWidget);

      // dart:io's idle-connection-pool timer is a *fake* Timer in this test
      // zone (bound to the fake clock, not real time) — advance it past its
      // 15s expiry so flutter_test's teardown doesn't trip on it.
      await tester.pump(const Duration(seconds: 16));
    });
  }
}
