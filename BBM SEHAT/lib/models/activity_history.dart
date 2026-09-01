/// One bar's worth of data from GET /api/activity/history — a single day
/// (weekly period) or a single week (monthly period, where date/targetMet
/// are omitted since a "target met" concept doesn't apply to a week total).
class ActivityHistoryEntry {
  final String label;
  final String? date;
  final int steps;
  final bool? targetMet;

  const ActivityHistoryEntry({
    required this.label,
    required this.steps,
    this.date,
    this.targetMet,
  });

  factory ActivityHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ActivityHistoryEntry(
      label: json['label'] as String,
      steps: json['steps'] as int,
      date: json['date'] as String?,
      targetMet: json['target_met'] as bool?,
    );
  }
}

/// Mirrors the "data" object of GET /api/activity/history's JSON response.
class ActivityHistory {
  final String period;
  final int averageDailySteps;
  final int targetSteps;
  final List<ActivityHistoryEntry> entries;

  const ActivityHistory({
    required this.period,
    required this.averageDailySteps,
    required this.targetSteps,
    required this.entries,
  });

  factory ActivityHistory.fromJson(Map<String, dynamic> json) {
    return ActivityHistory(
      period: json['period'] as String,
      averageDailySteps: json['average_daily_steps'] as int,
      targetSteps: json['target_steps'] as int,
      entries: (json['entries'] as List)
          .map((e) => ActivityHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
