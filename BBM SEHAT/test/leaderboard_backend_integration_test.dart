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

/// Drives the real Papan Peringkat feature end to end: correct weekly
/// ranking order, the own_division/all_employees/by_division scope swap,
/// per-account "is_me" isolation, the null rank_change for a division with
/// no prior-week data, and Beranda's summary card reflecting each account's
/// own division.
class _InMemoryTokenStorage implements TokenStorage {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

const _backendPath = '/Users/ptborobudurbumimandiri/APP/bbm-sehat-backend';
const _mysqlBin = '/Applications/MAMP/Library/bin/mysql80/bin/mysql';

/// Farhan (8), Gofar (9) and Super Admin (1) are the only employees this
/// whole suite ever awards points to — wiping just these three keeps every
/// run's ranking numbers deterministic regardless of leftover data from
/// other test files or manual curl testing.
Future<void> _resetItDivisionPoints() async {
  await Process.run(_mysqlBin, [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-e',
    'DELETE FROM point_transactions WHERE employee_id IN (1, 8, 9); '
        'DELETE FROM daily_activity_logs WHERE employee_id IN (1, 8, 9) '
        'AND activity_date >= CURDATE() - INTERVAL 10 DAY;',
  ]);
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('id_ID');
    AuthService.debugOverrideStorage(_InMemoryTokenStorage());

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

  // Pure backend checks (no widget tree) — precise control over exactly how
  // many points each account has, which the UI's random step-sync button
  // can't reliably give.
  test('own_division ranks by weekly points, highest first, with distinct totals', () async {
    await _resetItDivisionPoints();

    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };

    Future<String> login(String email, String password) async {
      final res = await probe.post('/login', data: {'employee_code': email, 'password': password});
      return res.data['token'] as String;
    }

    Future<void> sync(String token, int steps) async {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await probe.post(
        '/activity/sync',
        data: {'activity_date': today, 'steps': steps},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }

    final farhanToken = await login('BBM-005', TestCredentials.farhanPassword);
    final gofarToken = await login('BBM-006', TestCredentials.gofarPassword);

    // Farhan: today only -> 10 weekly points.
    await sync(farhanToken, 8500);
    // Gofar: 4-day streak backfill (2 days fall before this Monday, so
    // don't count toward the weekly window) + today -> 50 weekly points.
    final seed = await Process.run('php', ['artisan', 'test:seed-streak', '9'], workingDirectory: _backendPath);
    expect(seed.exitCode, 0, reason: 'seed command output: ${seed.stdout}\n${seed.stderr}');
    await sync(gofarToken, 8600);
    // Super Admin: left untouched -> 0 points.

    final res = await probe.get(
      '/leaderboard',
      queryParameters: {'scope': 'own_division', 'period': 'weekly'},
      options: Options(headers: {'Authorization': 'Bearer $farhanToken'}),
    );
    final entries = (res.data['data']['entries'] as List).cast<Map<String, dynamic>>();

    Map<String, dynamic> byName(String name) => entries.firstWhere((e) => e['name'] == name);

    expect(byName('Gofar')['rank'], 1);
    expect(byName('Gofar')['total_points'], 50);
    expect(byName('Farhan')['rank'], 2);
    expect(byName('Farhan')['total_points'], 10);
    expect(byName('Farhan')['is_me'], true, reason: 'the token used to call this belongs to Farhan');
    expect(byName('Super Admin')['rank'], 3);
    expect(byName('Super Admin')['total_points'], 0);

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $farhanToken'}));
    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $gofarToken'}));
  });

  test('all_employees lists individuals across divisions; by_division aggregates per division', () async {
    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };
    final token = (await probe.post('/login', data: {
      'employee_code': 'BBM-005',
      'password': TestCredentials.farhanPassword,
    }))
        .data['token'] as String;

    final allEmployees = await probe.get(
      '/leaderboard',
      queryParameters: {'scope': 'all_employees', 'period': 'weekly'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final individualEntries = (allEmployees.data['data']['entries'] as List).cast<Map<String, dynamic>>();
    // Individuals: "name" is a person, "sub" is their division.
    expect(individualEntries.any((e) => e['name'] == 'Farhan' && e['sub'] == 'IT'), isTrue,
        reason: 'all_employees must show individual people with their division as sub');

    final byDivision = await probe.get(
      '/leaderboard',
      queryParameters: {'scope': 'by_division', 'period': 'weekly'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final divisionEntries = (byDivision.data['data']['entries'] as List).cast<Map<String, dynamic>>();
    // Aggregates: "name" is the division itself, "sub" is an employee count.
    expect(divisionEntries.any((e) => e['name'] == 'IT' && (e['sub'] as String).contains('karyawan')), isTrue,
        reason: 'by_division must show divisions themselves, aggregated, not individual people');
    expect(divisionEntries.any((e) => e['name'] == 'Farhan'), isFalse,
        reason: 'by_division must never list an individual person as an entry');

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  test('is_me flags whichever account is actually logged in, never a different one', () async {
    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };

    Future<String> meAccordingToLeaderboard(String email, String password) async {
      final token = (await probe.post('/login', data: {'employee_code': email, 'password': password}))
          .data['token'] as String;
      final res = await probe.get(
        '/leaderboard',
        queryParameters: {'scope': 'own_division', 'period': 'weekly'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final entries = (res.data['data']['entries'] as List).cast<Map<String, dynamic>>();
      final mine = entries.firstWhere((e) => e['is_me'] == true);
      await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
      return mine['name'] as String;
    }

    expect(await meAccordingToLeaderboard('BBM-005', TestCredentials.farhanPassword), 'Farhan');
    // Gofar has never gone through the change-password screen, but the
    // token a login call issues is fully valid for any API call regardless.
    expect(await meAccordingToLeaderboard('BBM-006', TestCredentials.gofarPassword), 'Gofar');
  });

  test('a division with no prior-week data gets a null rank_change, not a fabricated one', () async {
    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };

    // Andi Pratama (Marketing) has never earned a point in this whole
    // database — the admin reset-password flow (same pattern
    // login_backend_integration_test.dart uses for Farhan) gets a fresh
    // temporary password so this stays re-runnable.
    final adminToken =
        (await probe.post('/login', data: {'employee_code': 'BBM-0001', 'password': TestCredentials.adminPassword}))
            .data['token'] as String;
    final reset = await probe.post('/admin/employees/2/reset-password',
        options: Options(headers: {'Authorization': 'Bearer $adminToken'}));
    final tempPassword = reset.data['temporary_password'] as String;

    final token = (await probe.post('/login', data: {
      'employee_code': 'BBM-0002',
      'password': tempPassword,
    }))
        .data['token'] as String;

    final res = await probe.get(
      '/leaderboard/my-position',
      queryParameters: {'scope': 'own_division', 'period': 'weekly'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = res.data['data'] as Map<String, dynamic>;
    expect(data['sub'], 'Marketing');
    expect(data['rank_change'], isNull,
        reason: 'Marketing has never earned any points, so there is nothing real to compare against');

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  // Real UI check: Beranda's leaderboard summary card must show the
  // logged-in employee's own division (not a hardcoded one), and must not
  // invent a naik/turun claim when there's genuinely nothing to compare.
  testWidgets("Beranda's leaderboard card shows the right division per account, and a neutral message with no prior data",
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

    Future<void> loginAndWaitForBeranda(String identifier, String password) async {
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

    // 1) Farhan (IT) -> the card must say "Divisi IT".
    await loginAndWaitForBeranda('BBM-005', TestCredentials.farhanPassword);
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget);
    expect(find.textContaining('Divisi IT minggu ini'), findsOneWidget);

    employeeState().clear();
    activityState().clear();
    pointsState().clear();
    leaderboardState().clear();
    await tester.runAsync(() => appState().logout());
    await tester.pumpAndSettle();

    // 2) Reset a Marketing employee's password (self-contained — doesn't
    // depend on the earlier plain test having already done this) and log
    // in for real: temp password -> mandatory change-password -> Beranda.
    final tempPassword = await tester.runAsync(() async {
      final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        return HttpClient()..idleTimeout = Duration.zero;
      };
      final adminToken = (await probe.post('/login', data: {
        'employee_code': 'BBM-0001',
        'password': TestCredentials.adminPassword,
      }))
          .data['token'] as String;
      final reset = await probe.post('/admin/employees/2/reset-password',
          options: Options(headers: {'Authorization': 'Bearer $adminToken'}));
      return reset.data['temporary_password'] as String;
    });

    await tester.runAsync(() => appState().login('BBM-0002', tempPassword!));
    await tester.pumpAndSettle();
    expect(find.text('Buat Password Baru'), findsOneWidget);

    await tester.runAsync(() async {
      await appState().submitNewPassword(TestCredentials.andiPassword);
      await tester.pump(const Duration(milliseconds: 400));
      var attempts = 0;
      while ((activityState().isLoading || pointsState().isLoading || leaderboardState().isLoadingMyPosition) &&
          attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget);

    // Marketing has never earned a point in this database, so there's no
    // real prior week to compare against — the card must say so plainly,
    // not invent a "naik/turun N peringkat" claim.
    expect(find.textContaining('Divisi Marketing minggu ini.'), findsOneWidget,
        reason: 'no naik/turun claim when there is no prior-period data to compare against');
    expect(find.textContaining('naik'), findsNothing);
    expect(find.textContaining('turun'), findsNothing);

    // dart:io's idle-connection-pool timer is a *fake* Timer in this test
    // zone (bound to the fake clock, not real time) — advance it past its
    // 15s expiry so flutter_test's teardown doesn't trip on it.
    await tester.pump(const Duration(seconds: 16));
  });
}
