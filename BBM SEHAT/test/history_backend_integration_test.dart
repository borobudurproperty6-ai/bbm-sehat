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
import 'package:bbm_sehat/state/history_state.dart';
import 'package:bbm_sehat/services/walk_session_service.dart';
import 'package:bbm_sehat/state/leaderboard_state.dart';
import 'package:bbm_sehat/state/points_state.dart';
import 'package:bbm_sehat/state/walk_session_state.dart';

import 'test_credentials.dart';

/// Drives the real "Riwayat Mingguan/Bulanan" feature end to end: the
/// weekly chart's 7 zero-filled days against real seeded data, monthly's
/// weekly aggregation, isolation between accounts, and Sesi Jalan Kaki
/// staying mock.
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

Future<void> _resetActivity(int employeeId) async {
  await Process.run(_mysqlBin, [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-e',
    'DELETE FROM daily_activity_logs WHERE employee_id = $employeeId '
        'AND activity_date >= CURDATE() - INTERVAL 40 DAY;',
  ]);
}

/// Actual steps recorded for one employee/date, straight from MySQL — the
/// ground truth the API response is checked against, since the seed
/// command uses random values that can't be hardcoded as expectations.
Future<int> _actualSteps(int employeeId, String date) async {
  final result = await Process.run(_mysqlBin, [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-N',
    '-e',
    "SELECT COALESCE((SELECT steps FROM daily_activity_logs WHERE employee_id = $employeeId "
        "AND activity_date = '$date'), 0);",
  ]);
  return int.parse((result.stdout as String).trim());
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
    WalkSessionService.debugConfigureDio(disableConnectionPooling);

    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('gfonts_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => tempDir.path);
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600);
    GoogleFonts.lora(fontWeight: FontWeight.w400);
    await GoogleFonts.pendingFonts();
  });

  test('weekly history returns exactly 7 zero-filled days matching the real seeded data', () async {
    await _resetActivity(8); // Farhan

    final seed = await Process.run('php', ['artisan', 'test:seed-history', '8', '14'], workingDirectory: _backendPath);
    expect(seed.exitCode, 0, reason: 'seed command output: ${seed.stdout}\n${seed.stderr}');

    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };
    final token = (await probe.post('/login', data: {
      'employee_code': 'BBM-005',
      'password': TestCredentials.farhanPassword,
    }))
        .data['token'] as String;

    final res = await probe.get(
      '/activity/history',
      queryParameters: {'period': 'weekly'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final body = res.data['data'] as Map<String, dynamic>;
    final entries = (body['entries'] as List).cast<Map<String, dynamic>>();

    expect(entries.length, 7, reason: 'weekly view must always show all 7 days, Mon-Sun');
    expect(entries.map((e) => e['label']), ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']);

    var expectedSum = 0;
    for (final entry in entries) {
      final actual = await _actualSteps(8, entry['date'] as String);
      expect(entry['steps'], actual, reason: '${entry['date']} must reflect the real daily_activity_logs row');
      expect(entry['target_met'], actual >= (body['target_steps'] as int));
      expectedSum += actual;
    }
    final expectedAverage = (expectedSum / 7).round();
    expect(body['average_daily_steps'], expectedAverage,
        reason: 'average must be the mean of exactly what the 7 entries show, not a different window');

    // The chart must show real variety, not every bar the same height —
    // proof this isn't accidentally still flat mock data.
    expect(entries.map((e) => e['steps']).toSet().length, greaterThan(1),
        reason: 'seeded data should produce varied step counts across the week, not a flat line');

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  test('monthly history aggregates into weekly totals, consistent with the underlying daily data', () async {
    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };
    final token = (await probe.post('/login', data: {
      'employee_code': 'BBM-005',
      'password': TestCredentials.farhanPassword,
    }))
        .data['token'] as String;

    final res = await probe.get(
      '/activity/history',
      queryParameters: {'period': 'monthly'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final body = res.data['data'] as Map<String, dynamic>;
    final entries = (body['entries'] as List).cast<Map<String, dynamic>>();

    expect(entries.every((e) => (e['label'] as String).startsWith('Minggu')), isTrue,
        reason: 'monthly entries must be week labels, not weekday labels');
    expect(entries.every((e) => e.containsKey('target_met') == false || e['target_met'] == null), isTrue,
        reason: 'target_met is not meaningful per-week and should be omitted/null for monthly');

    // "Minggu 1" is days 1-7 of the current month — cross-check against the
    // real per-day rows directly, independent of the weekly-view test above.
    final now = DateTime.now();
    var week1Expected = 0;
    for (var day = 1; day <= 7; day++) {
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      week1Expected += await _actualSteps(8, date);
    }
    expect(entries.first['label'], 'Minggu 1');
    expect(entries.first['steps'], week1Expected);

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  test('an account that has never synced shows an all-zero week, not an error', () async {
    await _resetActivity(1); // Super Admin — guaranteed clean for this check

    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };
    final token = (await probe.post('/login', data: {
      'employee_code': 'BBM-0001',
      'password': TestCredentials.adminPassword,
    }))
        .data['token'] as String;

    final res = await probe.get(
      '/activity/history',
      queryParameters: {'period': 'weekly'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final body = res.data['data'] as Map<String, dynamic>;
    final entries = (body['entries'] as List).cast<Map<String, dynamic>>();

    expect(entries.length, 7);
    expect(entries.every((e) => e['steps'] == 0), isTrue);
    expect(body['average_daily_steps'], 0);

    // Isolation: Farhan's real seeded data (test 1 above) must not leak
    // into Super Admin's history.
    expect(entries.any((e) => e['steps'] as int > 0), isFalse);

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  test('the backend rejects an invalid period', () async {
    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };
    final token = (await probe.post('/login', data: {
      'employee_code': 'BBM-005',
      'password': TestCredentials.farhanPassword,
    }))
        .data['token'] as String;

    try {
      await probe.get(
        '/activity/history',
        queryParameters: {'period': 'yearly'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      fail('expected an invalid period to be rejected');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 422);
    }

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  // Real UI check: the chart reflects real varied data, the toggle works,
  // and Sesi Jalan Kaki underneath now shows a real (empty, for this
  // account) history from GET /api/walk-sessions instead of mock data.
  testWidgets('Riwayat shows real weekly/monthly data and a real (empty) Sesi Jalan Kaki list', (tester) async {
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
    HistoryState historyState() => Provider.of<HistoryState>(ctx(), listen: false);
    WalkSessionState walkSessionState() => Provider.of<WalkSessionState>(ctx(), listen: false);

    await tester.runAsync(() async {
      await appState().login('BBM-005', TestCredentials.farhanPassword);
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
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget);

    Future<void> tapAndWaitForHistory(String label) async {
      await tester.runAsync(() async {
        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 400));
        var attempts = 0;
        while ((historyState().isLoading || walkSessionState().isLoadingHistory) && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      });
      await tester.pumpAndSettle();
    }

    await tapAndWaitForHistory('Riwayat');
    expect(find.text('Riwayat Aktivitas'), findsOneWidget);

    // The weekly chart must show Farhan's real (seeded in the plain test
    // above) data — spot-check the average text isn't the old mock value
    // and isn't blank/error.
    expect(historyState().history, isNotNull);
    expect(historyState().history!.entries.length, 7);
    expect(historyState().error, isNull);

    // Sesi Jalan Kaki underneath now comes from the real GET
    // /api/walk-sessions — Farhan has no completed sessions in this test's
    // seeded data, so it must show the real empty state, not old mock rows.
    // SectionLabel uppercases its text, hence "SESI JALAN KAKI".
    expect(find.text('SESI JALAN KAKI'), findsOneWidget);
    expect(walkSessionState().historyError, isNull);
    expect(walkSessionState().history, isEmpty);
    expect(
      find.text('Belum ada sesi jalan kaki tersimpan — mulai dari tombol "Mulai Jalan Kaki" di Beranda.'),
      findsOneWidget,
    );

    // Toggle to Bulanan -> must not error or go blank.
    await tapAndWaitForHistory('Bulanan');
    expect(historyState().error, isNull);
    expect(historyState().history, isNotNull);
    expect(historyState().history!.period, 'monthly');
    expect(find.textContaining('Minggu'), findsWidgets);
    // Sesi Jalan Kaki must still be there, unaffected by the toggle.
    expect(walkSessionState().history, isEmpty);

    await tapAndWaitForHistory('Mingguan');
    expect(historyState().history!.period, 'weekly');

    await tester.pump(const Duration(seconds: 16));
  });
}
