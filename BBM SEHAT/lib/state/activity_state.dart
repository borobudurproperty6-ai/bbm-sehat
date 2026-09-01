import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/health_connect_service.dart';

/// Today's real step count for the logged-in employee (GET
/// /api/activity/today), synced from real Health Connect data — either
/// automatically on app open, or via the "Sinkron Sekarang" button.
class ActivityState extends ChangeNotifier {
  int steps = 0;
  double distanceMeters = 0;
  int targetSteps = 8000; // sane fallback shown before the first load
  bool isLoading = false;
  bool isSyncing = false;
  String? error;
  bool sessionExpired = false;

  /// True once a Health Connect sync has been attempted without
  /// permission — the UI uses this to show a rationale dialog instead of
  /// silently failing.
  bool needsHealthConnectPermission = false;

  /// 50,000 steps/day (~35km on foot) is already past what a real person
  /// walks — a Health Connect aggregation bug or sensor glitch is the far
  /// more likely explanation. Checked here too (not just server-side) so
  /// a bad reading never even gets shown as "synced" locally, and the
  /// round trip to the backend is skipped entirely — same
  /// client-defends-too, server-is-authoritative pattern as the GPS noise
  /// filter in WalkSessionState.
  static const int _maxPlausibleStepsPerDay = 50000;

  double get progress => targetSteps > 0 ? (steps / targetSteps).clamp(0, 1).toDouble() : 0;

  /// Flips isLoading on synchronously, with no await in between. Callers
  /// that need to do async work (e.g. checking Health Connect permission)
  /// before deciding whether to call [fetchToday] or [syncNow] should call
  /// this first — otherwise isLoading stays false for that entire
  /// round-trip, which is both a real UX flicker risk (the step ring
  /// briefly renders as "not loading" before jumping to loading) and
  /// breaks any code that polls isLoading to know a fetch is underway.
  void beginLoading() {
    isLoading = true;
    notifyListeners();
  }

  Future<void> fetchToday() async {
    isLoading = true;
    error = null;
    sessionExpired = false;
    notifyListeners();

    final result = await ActivityService.instance.fetchToday();

    isLoading = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.activity != null) {
      steps = result.activity!.steps;
      distanceMeters = result.activity!.distanceMeters;
      targetSteps = result.activity!.targetSteps;
    } else {
      // Failed to load — show 0 steps rather than stale data or a crash.
      steps = 0;
      error = result.errorMessage ?? 'Gagal memuat data aktivitas.';
    }
    notifyListeners();
  }

  /// Reads today's step count from Health Connect and syncs it to the
  /// backend (source='health_connect'). Assumes permission has already
  /// been granted — callers (see BerandaScreen) are responsible for
  /// showing a rationale dialog and requesting permission first when it
  /// hasn't been, since that's a UI concern this state class shouldn't own.
  Future<void> syncNow() async {
    if (isSyncing) return;

    isSyncing = true;
    error = null;
    needsHealthConnectPermission = false;
    notifyListeners();

    if (!await HealthConnectService.instance.hasPermission()) {
      isSyncing = false;
      needsHealthConnectPermission = true;
      notifyListeners();
      return;
    }

    final healthSteps = await HealthConnectService.instance.stepsForDate(DateTime.now());
    if (healthSteps > _maxPlausibleStepsPerDay) {
      isSyncing = false;
      error = 'Data langkah dari Health Connect tidak masuk akal ($healthSteps langkah) — sinkron dibatalkan.';
      notifyListeners();
      return;
    }

    final result = await ActivityService.instance.syncToday(steps: healthSteps);

    if (result.unauthorized) {
      isSyncing = false;
      sessionExpired = true;
      notifyListeners();
      return;
    }

    if (result.success) {
      await fetchToday(); // pulls the just-synced value back from the server
    } else {
      error = result.errorMessage;
    }

    isSyncing = false;
    notifyListeners();
  }

  void clear() {
    steps = 0;
    distanceMeters = 0;
    targetSteps = 8000;
    isLoading = false;
    isSyncing = false;
    error = null;
    sessionExpired = false;
    needsHealthConnectPermission = false;
    notifyListeners();
  }
}
