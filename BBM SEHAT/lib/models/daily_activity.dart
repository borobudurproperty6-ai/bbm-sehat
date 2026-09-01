/// Mirrors GET /api/activity/today's JSON shape — today's real step count
/// for the logged-in employee, plus the step target that applies to them.
class DailyActivity {
  final String activityDate;
  final int steps;
  final double distanceMeters;
  final int targetSteps;

  const DailyActivity({
    required this.activityDate,
    required this.steps,
    required this.distanceMeters,
    required this.targetSteps,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      activityDate: json['activity_date'] as String,
      steps: json['steps'] as int,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      targetSteps: json['target_steps'] as int,
    );
  }
}
