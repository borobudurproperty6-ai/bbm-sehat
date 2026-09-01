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

/// Drives the real "Sinkronisasi Langkah Harian" feature end to end: the
/// "Sync Sekarang" button against the live backend, the upsert-not-duplicate
/// behaviour verified directly in MySQL, and isolation between two real
/// employee accounts.
class _InMemoryTokenStorage implements TokenStorage {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

/// Counts today's daily_activity_logs rows for one employee, straight from
/// MySQL — the strongest possible check that re-syncing updates in place
/// instead of inserting a second row.
Future<int> _todayRowCountFor(int employeeId) async {
  final result = await Process.run('/Applications/MAMP/Library/bin/mysql80/bin/mysql', [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-N', // skip the column header row
    '-e',
    'SELECT COUNT(*) FROM daily_activity_logs WHERE employee_id = $employeeId AND activity_date = CURDATE();',
  ]);
  return int.parse((result.stdout as String).trim());
}

/// Deletes today's daily_activity_logs row for one employee, so the
/// "never synced today" check is re-runnable — without this, Super Admin
/// would already have a row from this same file's own previous run today
/// and the "shows 0" assertion would fail on any rerun after the first.
Future<void> _deleteTodayRowFor(int employeeId) async {
  await Process.run('/Applications/MAMP/Library/bin/mysql80/bin/mysql', [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-e',
    'DELETE FROM daily_activity_logs WHERE employee_id = $employeeId AND activity_date = CURDATE();',
  ]);
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

  testWidgets(
      'Sync Sekarang updates the ring and upserts in place; accounts never mix step data',
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

    // Same zone constraint as the other backend-integration tests: the
    // postFrameCallback that starts a fetch captures whatever zone is active
    // when it's *scheduled* (during login/tap), not when it fires — so the
    // triggering action and the wait for it to resolve both have to happen
    // inside one runAsync, or the fetch's Future never resolves.
    Future<void> loginAndWaitForEmployee(String identifier, String password) async {
      await tester.runAsync(() async {
        await appState().login(identifier, password);
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

    // A sync can award points (daily target / streak) and shift this
    // week's ranking, so BerandaScreen's sync handler chains PointsState
    // and LeaderboardState refreshes right after the activity sync
    // resolves — waiting only on isSyncing would return while those
    // chained fetches are still in flight in the background.
    Future<void> tapSyncAndWait() async {
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.sync));
        await tester.pump(const Duration(milliseconds: 200));
        var attempts = 0;
        while (activityState().isSyncing && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        attempts = 0;
        while ((pointsState().isLoading || leaderboardState().isLoadingMyPosition) && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      });
      await tester.pumpAndSettle();
    }

    // 1) Login as Farhan. Whatever steps he's already showing (this file may
    // have synced him on an earlier run), note it before syncing so the
    // "changed" check below works regardless of run history.
    await loginAndWaitForEmployee('BBM-005', TestCredentials.farhanPassword);
    expect(activityState().error, isNull,
        reason: 'a never-synced or already-synced account must not surface an error');
    final farhanBefore = activityState().steps;

    // 2) Tap "Sync Sekarang" -> the ring shows the freshly synced number.
    await tapSyncAndWait();
    final farhanAfterFirstSync = activityState().steps;
    expect(farhanAfterFirstSync, inInclusiveRange(3000, 9000));
    expect(farhanAfterFirstSync, isNot(farhanBefore),
        reason: 'a fresh random sync should produce a new step count');
    expect(find.text('$farhanAfterFirstSync'), findsOneWidget,
        reason: 'the ring must reflect the freshly synced steps');
    // Process.run spawns a real OS process and waits on real I/O — like
    // Dio calls elsewhere in this suite, that hangs forever unless it runs
    // inside runAsync, which escapes the test's fake-time zone.
    expect(await tester.runAsync(() => _todayRowCountFor(8)), 1,
        reason: 'first sync of the day upserts, never duplicates');

    // 3) Sync again the same day -> value changes again, still exactly one row.
    await tapSyncAndWait();
    final farhanAfterSecondSync = activityState().steps;
    expect(farhanAfterSecondSync, inInclusiveRange(3000, 9000));
    expect(find.text('$farhanAfterSecondSync'), findsOneWidget);
    expect(await tester.runAsync(() => _todayRowCountFor(8)), 1,
        reason: 're-syncing the same day must update the existing row, not insert a second one');

    // Mirrors ProfilScreen's actual "Keluar" handler (clear employee +
    // activity data, then log out) — the real app's only reachable logout
    // path already does this.
    employeeState().clear();
    activityState().clear();
    pointsState().clear();
    leaderboardState().clear();
    await tester.runAsync(() => appState().logout());
    await tester.pumpAndSettle();

    // 4) A different account that has never synced today shows 0 steps, not
    // an error and not Farhan's data. Clear any row this file's own earlier
    // run left behind so this stays true on every rerun, not just the first.
    await tester.runAsync(() => _deleteTodayRowFor(1));
    await loginAndWaitForEmployee('BBM-0001', TestCredentials.adminPassword);
    expect(activityState().error, isNull);
    expect(activityState().steps, 0, reason: 'never having synced today must show 0, not an error');
    expect(find.text('0'), findsOneWidget);

    // 5) Syncing this second account must not touch Farhan's row.
    await tapSyncAndWait();
    expect(activityState().steps, inInclusiveRange(3000, 9000));
    expect(await tester.runAsync(() => _todayRowCountFor(1)), 1);
    expect(await tester.runAsync(() => _todayRowCountFor(8)), 1,
        reason: "syncing Super Admin's steps must not create or touch Farhan's row");

    // dart:io's idle-connection-pool timer is a *fake* Timer in this test
    // zone (bound to the fake clock, not real time) — advance it past its
    // 15s expiry so flutter_test's teardown doesn't trip on it.
    await tester.pump(const Duration(seconds: 16));
  });

  test('the backend rejects a negative step count', () async {
    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };

    // Gofar has never gone through the change-password screen, but the
    // token a login call issues is fully valid for any API call regardless —
    // it's the app's UI that gates on must_change_password, not the token.
    final login = await probe.post('/login', data: {
      'employee_code': 'BBM-006',
      'password': TestCredentials.gofarPassword,
    });
    final token = login.data['token'] as String;

    try {
      await probe.post(
        '/activity/sync',
        data: {
          'activity_date': DateTime.now().toIso8601String().substring(0, 10),
          'steps': -5,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      fail('expected a negative step count to be rejected');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 422);
    }

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });
}
