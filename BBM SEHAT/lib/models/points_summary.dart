/// Mirrors GET /api/points/summary's JSON shape.
class PointsSummary {
  final int totalPoints;
  final int pointsToday;
  final int currentStreakDays;

  const PointsSummary({
    required this.totalPoints,
    required this.pointsToday,
    required this.currentStreakDays,
  });

  factory PointsSummary.fromJson(Map<String, dynamic> json) {
    return PointsSummary(
      totalPoints: json['total_points'] as int,
      pointsToday: json['points_today'] as int,
      currentStreakDays: json['current_streak_days'] as int,
    );
  }
}
