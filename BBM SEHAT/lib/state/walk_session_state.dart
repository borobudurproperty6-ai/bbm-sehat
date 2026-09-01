import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/walk_session.dart';
import '../services/location_service.dart';
import '../services/walk_session_service.dart';

enum WalkTrackingStatus { idle, running, paused, done }

/// Real GPS walk tracking — replaces the old fake-timer simulation in
/// AppState. Owns the live position stream, the point trail sent to the
/// backend on finish, and the authoritative session data the backend
/// returns (distance/points are always taken from that response, never
/// trusted from the client-side running total, which is only for the live
/// display).
class WalkSessionState extends ChangeNotifier {
  WalkTrackingStatus status = WalkTrackingStatus.idle;
  int? sessionId;
  int elapsedSeconds = 0;
  final List<RoutePoint> points = [];
  double distanceMeters = 0;

  /// The backend's response to /finish — authoritative distance, polyline,
  /// and points_awarded for the session-summary screen.
  WalkSession? lastFinishedSession;

  bool isStarting = false;
  bool isFinishing = false;
  String? error;
  bool sessionExpired = false;

  /// The Riwayat screen's "Sesi Jalan Kaki" history — a separate slice
  /// from the live-tracking fields above, same pattern LeaderboardState
  /// uses for its own two independent slices.
  List<WalkSession> history = [];
  bool isLoadingHistory = false;
  String? historyError;
  bool historySessionExpired = false;

  Timer? _ticker;
  StreamSubscription<Position>? _positionSub;

  double get distanceKm => distanceMeters / 1000;
  String get distanceKmFormatted => distanceKm.toStringAsFixed(2).replaceAll('.', ',');

  String get elapsedFormatted {
    final mm = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// Steps aren't measured by GPS — this is a walking-pace estimate purely
  /// for the live "Langkah" stat during tracking, the same ratio the old
  /// mock used. Real step counts come from Health Connect (Bagian D), not
  /// this session.
  int get liveSteps => (distanceMeters * 1.38).round();

  /// True once permission has been explicitly refused (not just "not asked
  /// yet") — lets the UI show a clear explanation instead of a silent
  /// no-op when the start button is tapped.
  bool permissionDenied = false;

  Future<bool> start() async {
    isStarting = true;
    error = null;
    permissionDenied = false;
    notifyListeners();

    final permission = await LocationService.instance.ensurePermission();
    if (permission != LocationPermissionOutcome.granted) {
      isStarting = false;
      permissionDenied = true;
      error = switch (permission) {
        LocationPermissionOutcome.serviceDisabled =>
          'Aktifkan Lokasi/GPS di perangkatmu untuk merekam rute jalan kaki.',
        LocationPermissionOutcome.deniedForever =>
          'Izin lokasi ditolak permanen — aktifkan lewat Pengaturan aplikasi untuk memakai fitur ini.',
        _ => 'Izin lokasi dibutuhkan untuk merekam rute jalan kaki.',
      };
      notifyListeners();
      return false;
    }

    final Position position;
    try {
      position = await LocationService.instance.currentPosition();
    } catch (_) {
      isStarting = false;
      error = 'Tidak bisa membaca lokasi sekarang, coba lagi.';
      notifyListeners();
      return false;
    }

    final result = await WalkSessionService.instance.start(
      startLat: position.latitude,
      startLng: position.longitude,
    );

    isStarting = false;
    if (result.unauthorized) {
      sessionExpired = true;
      notifyListeners();
      return false;
    }
    if (result.sessionId == null) {
      error = result.errorMessage;
      notifyListeners();
      return false;
    }

    sessionId = result.sessionId;
    elapsedSeconds = 0;
    distanceMeters = 0;
    points
      ..clear()
      ..add(RoutePoint(lat: position.latitude, lng: position.longitude, timestamp: position.timestamp));
    lastFinishedSession = null;
    status = WalkTrackingStatus.running;
    notifyListeners();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status != WalkTrackingStatus.running) return;
      elapsedSeconds += 1;
      notifyListeners();
    });

    _positionSub?.cancel();
    _positionSub = LocationService.instance.positionStream().listen((position) {
      if (status != WalkTrackingStatus.running) return; // drop fixes while paused
      final last = points.last;
      final newPoint = RoutePoint(lat: position.latitude, lng: position.longitude, timestamp: position.timestamp);
      final segmentMeters = _haversineMeters(last.lat, last.lng, newPoint.lat, newPoint.lng);
      final segmentSeconds = newPoint.timestamp.difference(last.timestamp).inMilliseconds / 1000;

      // Only count the segment's distance if it isn't GPS noise — but
      // always keep the point itself (and use it as the new baseline for
      // the next segment), otherwise every future reading would keep
      // looking like a huge jump from the stale last-good point forever.
      if (!_isGpsNoise(segmentMeters, segmentSeconds, isFirstFixAfterStart: points.length == 1)) {
        distanceMeters += segmentMeters;
      }
      points.add(newPoint);
      notifyListeners();
    });

    return true;
  }

  void togglePause() {
    if (status == WalkTrackingStatus.running) {
      status = WalkTrackingStatus.paused;
    } else if (status == WalkTrackingStatus.paused) {
      status = WalkTrackingStatus.running;
    }
    notifyListeners();
  }

  Future<void> finish() async {
    _ticker?.cancel();
    await _positionSub?.cancel();

    if (sessionId == null || points.length < 2) {
      // Too short to be a meaningful route (e.g. finished within the very
      // first GPS fix) — nothing worth submitting.
      status = WalkTrackingStatus.idle;
      notifyListeners();
      return;
    }

    isFinishing = true;
    notifyListeners();

    final result = await WalkSessionService.instance.finish(
      sessionId: sessionId!,
      endLat: points.last.lat,
      endLng: points.last.lng,
      durationSeconds: elapsedSeconds,
      points: points,
    );

    isFinishing = false;
    if (result.unauthorized) {
      sessionExpired = true;
      notifyListeners();
      return;
    }
    if (result.session == null) {
      error = result.errorMessage;
      notifyListeners();
      return;
    }

    lastFinishedSession = result.session;
    status = WalkTrackingStatus.done;
    notifyListeners();
  }

  /// "Hapus" on the summary screen — undoes the save + any awarded points
  /// server-side (finish() already persisted both), then resets to idle.
  Future<void> discardAndReset() async {
    final id = sessionId;
    if (id != null) {
      await WalkSessionService.instance.discard(id);
    }
    reset();
  }

  void reset() {
    _ticker?.cancel();
    _positionSub?.cancel();
    status = WalkTrackingStatus.idle;
    sessionId = null;
    elapsedSeconds = 0;
    distanceMeters = 0;
    points.clear();
    lastFinishedSession = null;
    isStarting = false;
    isFinishing = false;
    error = null;
    permissionDenied = false;
    notifyListeners();
  }

  Future<void> fetchHistory() async {
    isLoadingHistory = true;
    historyError = null;
    historySessionExpired = false;
    notifyListeners();

    final result = await WalkSessionService.instance.list();

    isLoadingHistory = false;
    if (result.unauthorized) {
      historySessionExpired = true;
    } else if (result.sessions != null) {
      history = result.sessions!;
    } else {
      history = [];
      historyError = result.errorMessage ?? 'Gagal memuat riwayat sesi jalan kaki.';
    }
    notifyListeners();
  }

  void clear() {
    sessionExpired = false;
    history = [];
    isLoadingHistory = false;
    historyError = null;
    historySessionExpired = false;
    reset();
  }

  /// Rejects a GPS segment as noise rather than real movement — matches
  /// the same two rules WalkSessionService::isGpsNoise applies server-side
  /// (backend re-validates independently, this is only for the live
  /// number shown while walking so it doesn't diverge wildly from what
  /// actually gets saved):
  /// - The very first live fix right after starting, if it's a huge jump
  ///   in under 5 seconds — e.g. the emulator's location snapping to a
  ///   different point via Extended Controls, or a stale/cached first fix.
  /// - Any segment implying faster than a human can plausibly walk/run
  ///   (20 km/h) — GPS multipath/reflection spikes.
  static const _firstFixJumpMeters = 500.0;
  static const _firstFixJumpSeconds = 5.0;
  static const _maxWalkingSpeedKmh = 20.0;

  bool _isGpsNoise(double segmentMeters, double segmentSeconds, {required bool isFirstFixAfterStart}) {
    if (isFirstFixAfterStart && segmentMeters > _firstFixJumpMeters && segmentSeconds < _firstFixJumpSeconds) {
      return true;
    }
    final speedKmh = segmentSeconds > 0 ? (segmentMeters / segmentSeconds) * 3.6 : double.infinity;
    return speedKmh > _maxWalkingSpeedKmh;
  }

  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  @override
  void dispose() {
    _ticker?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
