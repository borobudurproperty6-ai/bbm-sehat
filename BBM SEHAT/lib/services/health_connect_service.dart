import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around the `health` package (Health Connect on Android,
/// HealthKit on iOS later) — the rest of the app depends on this instead of
/// calling `Health()` directly. The package has no web implementation, and
/// under `flutter test` (VM, no real platform channels registered either)
/// every call throws MissingPluginException — this app's primary dev/test
/// platform is `flutter run -d chrome` / `flutter test`, and only this one
/// feature needs a real Android device/emulator. Every method here catches
/// that (and any other platform failure — e.g. Health Connect genuinely not
/// installed on the device) and fails soft with a safe fallback, rather
/// than crashing the caller.
class HealthConnectService {
  HealthConnectService._internal();
  static final HealthConnectService instance = HealthConnectService._internal();

  final Health _health = Health();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Requests ACTIVITY_RECOGNITION (required specifically for step data,
  /// separate from Health Connect's own permission dialog) and then Health
  /// Connect's own STEPS read permission.
  Future<bool> requestPermission() async {
    try {
      await _ensureConfigured();

      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) return false;

      const types = [HealthDataType.STEPS];
      final alreadyGranted = await _health.hasPermissions(types) ?? false;
      if (alreadyGranted) return true;

      return await _health.requestAuthorization(types);
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      await _ensureConfigured();
      return await _health.hasPermissions(const [HealthDataType.STEPS]) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Total steps Health Connect has recorded for [date] (defaults to
  /// today), from local midnight through now (or through end of day for a
  /// past date).
  Future<int> stepsForDate(DateTime date) async {
    try {
      await _ensureConfigured();

      final start = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final end = isToday ? now : start.add(const Duration(days: 1));

      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
