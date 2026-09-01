/// A single recorded GPS fix, as sent to/from the backend. [timestamp] is
/// the actual fix time (from geolocator's Position, not "when this object
/// was constructed") — both the live client-side distance calculation and
/// the backend's authoritative one need it to reject GPS jumps/spikes by
/// implied speed, not just raw distance.
class RoutePoint {
  final double lat;
  final double lng;
  final DateTime timestamp;

  const RoutePoint({required this.lat, required this.lng, required this.timestamp});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'timestamp': timestamp.toIso8601String()};
}

/// Mirrors one entry of GET /api/walk-sessions and the response of
/// POST /walk-sessions/start / PATCH /walk-sessions/{id}/finish.
class WalkSession {
  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final double? distanceMeters;
  final String? routePolyline;

  /// Only present on the PATCH .../finish response — null for
  /// GET /walk-sessions entries, where "just earned" doesn't apply.
  final int? pointsAwarded;

  const WalkSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.distanceMeters,
    this.routePolyline,
    this.pointsAwarded,
  });

  factory WalkSession.fromJson(Map<String, dynamic> json) {
    return WalkSession(
      id: json['id'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null ? null : DateTime.parse(json['ended_at'] as String),
      durationSeconds: json['duration_seconds'] as int?,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      routePolyline: json['route_polyline'] as String?,
      pointsAwarded: json['points_awarded'] as int?,
    );
  }
}
