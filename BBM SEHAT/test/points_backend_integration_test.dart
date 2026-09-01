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

/// Drives the real points feature end to end: daily-target points, the
/// rolling 5-day streak bonus (backfilled via `php artisan test:seed-streak`),
/// duplicate-prevention verified directly in MySQL, per-account isolation,
/// and Profil/Beranda showing consistent numbers for the same account.
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

/// Wipes one employee's point_transactions and recent daily_activity_logs,
/// so every run of this file starts from a known-empty slate regardless of
/// leftover data from manual curl testing or earlier runs.
Future<void> _resetPointsAndActivity(int employeeId) async {
  await Process.run(_mysqlBin, [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-e',
    'DELETE FROM point_transactions WHERE employee_id = $employeeId; '
        'DELETE FROM daily_activity_logs WHERE employee_id = $employeeId '
        'AND activity_date >= CURDATE() - INTERVAL 10 DAY;',
  ]);
}

Future<int> _pointTransactionCount(int employeeId) async {
  final result = await Process.run(_mysqlBin, [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-N',
    '-e',
    'SELECT COUNT(*) FROM point_transactions WHERE employee_id = $employeeId;',
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

    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('gfonts_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => tempDir.path);
    GoogleFonts.cormorantGaramond(fontWeight: FontWeight.w600);
    GoogleFonts.lora(fontWeight: FontWeight.w400);
    await GoogleFonts.pendingFonts();
  });

  // Pure backend checks (no widget tree) — precise control over exactly how
  // many steps get synced, which the temporary "Sync Sekarang" button's
  // random 3000-9000 range can't reliably give (target is 8000, so only
  // ~17% of random taps would land above it).
  test('daily target and streak points are awarded correctly, never duplicated, isolated per account', () async {
    await _resetPointsAndActivity(8); // Farhan
    await _resetPointsAndActivity(9); // Gofar

    final probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };

    Future<String> login(String employeeCode, String password) async {
      final res = await probe.post('/login', data: {'employee_code': employeeCode, 'password': password});
      return res.data['token'] as String;
    }

    Future<Map<String, dynamic>> sync(String token, int steps) async {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final res = await probe.post(
        '/activity/sync',
        data: {'activity_date': today, 'steps': steps},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return res.data['data'] as Map<String, dynamic>;
    }

    Future<Map<String, dynamic>> summary(String token) async {
      final res = await probe.get('/points/summary', options: Options(headers: {'Authorization': 'Bearer $token'}));
      return res.data['data'] as Map<String, dynamic>;
    }

    final farhanToken = await login('BBM-005', TestCredentials.farhanPassword);
    final gofarToken = await login('BBM-006', TestCredentials.gofarPassword);

    // 1) Below-target sync -> no points.
    await sync(farhanToken, 1000);
    var farhan = await summary(farhanToken);
    expect(farhan['total_points'], 0, reason: 'below-target steps must not award points');
    expect(farhan['points_today'], 0);

    // 2) Above-target sync, first time today -> +10.
    await sync(farhanToken, 8500);
    farhan = await summary(farhanToken);
    expect(farhan['total_points'], 10);
    expect(farhan['points_today'], 10);

    // 3) Re-sync the same day, still above target -> no duplicate award.
    await sync(farhanToken, 9200);
    farhan = await summary(farhanToken);
    expect(farhan['total_points'], 10, reason: 're-syncing the same day must not award points twice');
    expect(await _pointTransactionCount(8), 1, reason: 'exactly one point_transactions row for Farhan');

    // 4) Streak bonus: backfill 4 prior workdays via the dev-only seeder,
    // then a real sync for today completes the rolling 5-day streak.
    final seed = await Process.run('php', ['artisan', 'test:seed-streak', '9'], workingDirectory: _backendPath);
    expect(seed.exitCode, 0, reason: 'seed command output: ${seed.stdout}\n${seed.stderr}');

    await sync(gofarToken, 8600);
    final gofar = await summary(gofarToken);
    expect(gofar['current_streak_days'], 5);
    expect(gofar['points_today'], 30, reason: '10 (daily target) + 20 (streak bonus) on the day the streak completes');
    expect(gofar['total_points'], 70, reason: '5 days x 10 + one 20-point streak bonus');

    // 5) DB check: exactly the rows we expect, no duplicates — 5x
    // DAILY_TARGET_MET + 1x WEEKLY_STREAK_5.
    expect(await _pointTransactionCount(9), 6);

    // 6) Re-syncing Gofar again the same day must not duplicate the streak
    // bonus either.
    await sync(gofarToken, 8900);
    final gofarAgain = await summary(gofarToken);
    expect(gofarAgain['total_points'], 70);
    expect(await _pointTransactionCount(9), 6);

    // 7) Accounts stay isolated — Farhan's total is untouched by everything
    // done to Gofar above.
    final farhanFinal = await summary(farhanToken);
    expect(farhanFinal['total_points'], 10);

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $farhanToken'}));
    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $gofarToken'}));
  });

  // Real UI check: Beranda's "poin hari ini" tile and streak banner, and
  // Profil's "Total poin", must reflect the exact same PointsState — each
  // screen fetches independently, so this is what actually proves they
  // can't silently drift apart.
  testWidgets('Profil and Beranda show the same points and streak numbers', (tester) async {
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

    // Gofar's account has never been through the change-password screen,
    // so a real UI login for him would route to ChangePasswordScreen
    // instead of Beranda — use Farhan, who's already past that, same as
    // every other UI-driven test in this suite.
    await loginAndWaitForBeranda('BBM-005', TestCredentials.farhanPassword);
    expect(find.text('Mulai Jalan Kaki'), findsOneWidget);

    // Drive the exact same call the temporary "Sync Sekarang" button uses,
    // but with a controlled above-target value instead of its random
    // 3000-9000 range — deterministic setup, independent of whether the
    // other test in this file has already run.
    await tester.runAsync(() async {
      await ActivityService.instance.syncToday(steps: 8500);
      await activityState().fetchToday();
      await pointsState().fetchSummary();
    });
    await tester.pumpAndSettle();

    final berandaPointsToday = pointsState().pointsToday;
    final berandaStreak = pointsState().currentStreakDays;
    expect(berandaPointsToday, greaterThan(0), reason: 'an above-target sync must have awarded today\'s points');
    expect(find.text('+$berandaPointsToday'), findsOneWidget,
        reason: 'Beranda "poin hari ini" tile must show the real value');
    if (berandaStreak > 0) {
      expect(find.text('$berandaStreak hari beruntun!'), findsOneWidget,
          reason: 'Beranda streak banner must show the real streak');
    }

    // Navigate to Profil -> its own independent fetchSummary() must return
    // the same total the server already gave Beranda.
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

    final profilTotal = pointsState().totalPoints;
    expect(profilTotal, greaterThanOrEqualTo(berandaPointsToday));
    expect(find.text('$profilTotal'), findsOneWidget, reason: 'Profil "Total poin" must match the same PointsState');

    await tester.pump(const Duration(seconds: 16));
  });
}
