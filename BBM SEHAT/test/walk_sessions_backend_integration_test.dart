import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bbm_sehat/config/api_config.dart';

import 'test_credentials.dart';

/// Drives the real "Sesi Jalan Kaki" backend (Bagian A) end to end — no
/// widget tree, no Android device needed, exactly like the checklist says:
/// this part is fully curl/Dio-testable on its own before Android Studio
/// and an emulator are needed for Bagian C/D's real GPS + map rendering.
const _mysqlBin = '/Applications/MAMP/Library/bin/mysql80/bin/mysql';

Future<void> _resetWalkSessions(int employeeId) async {
  await Process.run(_mysqlBin, [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-e',
    "DELETE FROM point_transactions WHERE employee_id = $employeeId AND reference_type = 'walk_session'; "
        'DELETE FROM walk_sessions WHERE employee_id = $employeeId;',
  ]);
}

Future<int> _pointTransactionCount(int employeeId, {required String referenceType}) async {
  final result = await Process.run(_mysqlBin, [
    '-h127.0.0.1',
    '-P3306',
    '-uroot',
    '-proot',
    'bbm_sehat',
    '-N',
    '-e',
    "SELECT COUNT(*) FROM point_transactions WHERE employee_id = $employeeId AND reference_type = '$referenceType';",
  ]);
  return int.parse((result.stdout as String).trim());
}

/// A straight line of [count] points heading due north, each step roughly
/// [stepDegrees] of latitude apart (~111,320m per degree at the equator).
/// Timestamps are spread evenly across [durationSeconds] so the implied
/// speed of every segment stays realistic (well under the 20 km/h noise
/// threshold) unless a test deliberately wants otherwise.
List<Map<String, dynamic>> _straightRoute({
  required double startLat,
  required double lng,
  required int count,
  required double stepDegrees,
  int durationSeconds = 600,
}) {
  final start = DateTime.now().toUtc();
  final stepMs = count > 1 ? (durationSeconds * 1000) ~/ (count - 1) : 0;
  return List.generate(count, (i) => {
        'lat': startLat + stepDegrees * i,
        'lng': lng,
        'timestamp': start.add(Duration(milliseconds: stepMs * i)).toIso8601String(),
      });
}

void main() {
  late Dio probe;

  setUpAll(() {
    probe = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    (probe.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient()..idleTimeout = Duration.zero;
    };
  });

  Future<String> login(String email, String password) async {
    final res = await probe.post('/login', data: {'employee_code': email, 'password': password});
    return res.data['token'] as String;
  }

  Future<int> start(String token, {double lat = -0.5, double lng = 119.4}) async {
    final res = await probe.post(
      '/walk-sessions/start',
      data: {'start_lat': lat, 'start_lng': lng},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    expect(res.statusCode, 201);
    return res.data['data']['id'] as int;
  }

  Future<Map<String, dynamic>> finish(
    String token,
    int sessionId, {
    required List<Map<String, dynamic>> points,
    int durationSeconds = 600,
  }) async {
    final res = await probe.patch(
      '/walk-sessions/$sessionId/finish',
      data: {
        'end_lat': points.last['lat'],
        'end_lng': points.last['lng'],
        'duration_seconds': durationSeconds,
        'points': points,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  test('finishing a session >=500m calculates real distance, encodes a polyline, and awards +5 once', () async {
    await _resetWalkSessions(8); // Farhan
    final token = await login('BBM-005', TestCredentials.farhanPassword);

    // ~0.0054 degrees latitude per step ≈ 600m over 5 points (4 segments).
    final points = _straightRoute(startLat: -0.5000, lng: 119.4, count: 5, stepDegrees: 0.00135);
    final sessionId = await start(token);
    final result = await finish(token, sessionId, points: points);

    expect(result['status'], 'completed');
    expect(result['distance_meters'], greaterThan(0), reason: 'must be real Haversine distance, not the old 0,00');
    expect(result['distance_meters'], closeTo(600, 50));
    expect(result['route_polyline'], isNotEmpty);
    expect(await _pointTransactionCount(8, referenceType: 'walk_session'), 1);

    // Re-finishing the same session must be rejected, not double-award.
    try {
      await finish(token, sessionId, points: points);
      fail('expected finishing an already-completed session to be rejected');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 422);
    }
    expect(await _pointTransactionCount(8, referenceType: 'walk_session'), 1,
        reason: 'calling finish twice must not double-award points');

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  test('a session under 500m earns no points, but two separate sessions the same day each earn their own', () async {
    await _resetWalkSessions(8);
    final token = await login('BBM-005', TestCredentials.farhanPassword);

    // Short walk (~55m) — below the 500m threshold in point_rules.
    final shortId = await start(token);
    final shortResult = await finish(
      token,
      shortId,
      points: _straightRoute(startLat: -0.5000, lng: 119.4, count: 2, stepDegrees: 0.0005),
    );
    expect(shortResult['distance_meters'], lessThan(500));
    expect(await _pointTransactionCount(8, referenceType: 'walk_session'), 0);

    // A real >=500m walk later the same day must still earn its own points
    // — a "once per day" rule would wrongly block this.
    final longId = await start(token);
    final longResult = await finish(
      token,
      longId,
      points: _straightRoute(startLat: -0.5000, lng: 119.4, count: 5, stepDegrees: 0.00135),
    );
    expect(longResult['distance_meters'], greaterThanOrEqualTo(500));
    expect(await _pointTransactionCount(8, referenceType: 'walk_session'), 1);

    // And a second >=500m walk, same day again, must earn a second +5 —
    // this is the real regression check for the widened unique constraint.
    final secondLongId = await start(token);
    await finish(
      token,
      secondLongId,
      points: _straightRoute(startLat: -0.5000, lng: 119.4, count: 5, stepDegrees: 0.00135),
    );
    expect(await _pointTransactionCount(8, referenceType: 'walk_session'), 2,
        reason: 'two separate qualifying sessions the same day must both be rewarded');

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  test('GET /walk-sessions lists completed sessions and stays isolated per account', () async {
    await _resetWalkSessions(8);
    await _resetWalkSessions(1); // Super Admin

    final farhanToken = await login('BBM-005', TestCredentials.farhanPassword);
    final saToken = await login('BBM-0001', TestCredentials.adminPassword);

    final sessionId = await start(farhanToken);
    await finish(farhanToken, sessionId, points: _straightRoute(startLat: -0.5, lng: 119.4, count: 3, stepDegrees: 0.001));

    final farhanList = await probe.get('/walk-sessions', options: Options(headers: {'Authorization': 'Bearer $farhanToken'}));
    expect((farhanList.data['data'] as List).length, 1);

    final saList = await probe.get('/walk-sessions', options: Options(headers: {'Authorization': 'Bearer $saToken'}));
    expect((saList.data['data'] as List), isEmpty, reason: "Super Admin must not see Farhan's session");

    // Super Admin can't finish Farhan's session either.
    try {
      await finish(saToken, sessionId, points: _straightRoute(startLat: -0.5, lng: 119.4, count: 2, stepDegrees: 0.001));
      fail("expected finishing another employee's session to be rejected");
    } on DioException catch (e) {
      expect(e.response?.statusCode, 404);
    }

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $farhanToken'}));
    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $saToken'}));
  });

  test('a huge jump right after starting is excluded, but real walking from the new point still counts', () async {
    await _resetWalkSessions(8);
    final token = await login('BBM-005', TestCredentials.farhanPassword);
    final sessionId = await start(token);

    // Reproduces the emulator "Extended Controls > Location > Routes" bug
    // report: the very first live fix lands ~2004m from the start point,
    // 2 seconds later — a stale/jumped fix, not someone teleporting. Real
    // walking then continues from that new point (2 segments, ~55.7m
    // each, 60s apart -> ~3.3 km/h, well under the 20 km/h ceiling).
    final t0 = DateTime.now().toUtc();
    final points = [
      {'lat': -0.5000, 'lng': 119.4000, 'timestamp': t0.toIso8601String()},
      {'lat': -0.5180, 'lng': 119.4000, 'timestamp': t0.add(const Duration(seconds: 2)).toIso8601String()},
      {'lat': -0.5185, 'lng': 119.4000, 'timestamp': t0.add(const Duration(seconds: 62)).toIso8601String()},
      {'lat': -0.5190, 'lng': 119.4000, 'timestamp': t0.add(const Duration(seconds: 122)).toIso8601String()},
    ];

    final result = await finish(token, sessionId, points: points, durationSeconds: 122);

    // Only the two real ~55.7m segments should count (~111m total) — not
    // the ~2004m jump, which would make this closeTo(2115, ...) instead.
    expect(result['distance_meters'], closeTo(111, 20));

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  test('a mid-route speed spike is excluded from distance, without breaking the real segments around it', () async {
    await _resetWalkSessions(8);
    final token = await login('BBM-005', TestCredentials.farhanPassword);
    final sessionId = await start(token);

    // Segment 1 (real, ~55.7m/60s -> 3.3 km/h) -> segment 2 (spike,
    // ~334m/2s -> ~601 km/h, clearly not human) -> segment 3 (real again,
    // ~55.7m/60s). Not the first segment, so this isolates the speed rule
    // from the first-fix-jump rule tested above.
    final t0 = DateTime.now().toUtc();
    final points = [
      {'lat': -0.5000, 'lng': 119.4000, 'timestamp': t0.toIso8601String()},
      {'lat': -0.5005, 'lng': 119.4000, 'timestamp': t0.add(const Duration(seconds: 60)).toIso8601String()},
      {'lat': -0.5035, 'lng': 119.4000, 'timestamp': t0.add(const Duration(seconds: 62)).toIso8601String()},
      {'lat': -0.5040, 'lng': 119.4000, 'timestamp': t0.add(const Duration(seconds: 122)).toIso8601String()},
    ];

    final result = await finish(token, sessionId, points: points, durationSeconds: 122);

    // Only the two real ~55.7m segments count (~111m) — the ~334m spike
    // is excluded, not summed in as if it were real distance.
    expect(result['distance_meters'], closeTo(111, 20));

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });

  test('finish rejects fewer than 2 points', () async {
    final token = await login('BBM-005', TestCredentials.farhanPassword);
    final sessionId = await start(token);

    try {
      await finish(token, sessionId, points: [
        {'lat': -0.5, 'lng': 119.4, 'timestamp': DateTime.now().toIso8601String()},
      ]);
      fail('expected a single-point route to be rejected');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 422);
    }

    await probe.post('/logout', options: Options(headers: {'Authorization': 'Bearer $token'}));
  });
}
