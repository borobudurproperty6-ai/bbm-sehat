import '../config/api_config.dart';
import 'activity_history.dart';
import 'walk_session.dart';

String? _photoUrlOf(Map<String, dynamic> json) {
  final url = json['photo_url'] as String?;
  return url != null ? ApiConfig.resolveAssetUrl(url) : null;
}

/// Mirrors GET /api/monitoring/overview's response — see MONITORING_API.md
/// for field definitions (all figures are for the current week, Mon..today).
class MonitoringOverview {
  final int totalEmployeesActive;
  final double participationRateThisWeek;
  final int totalStepsThisWeek;
  final double totalKmThisWeek;
  final String periodStart;
  final String periodEnd;

  const MonitoringOverview({
    required this.totalEmployeesActive,
    required this.participationRateThisWeek,
    required this.totalStepsThisWeek,
    required this.totalKmThisWeek,
    required this.periodStart,
    required this.periodEnd,
  });

  factory MonitoringOverview.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    return MonitoringOverview(
      totalEmployeesActive: json['total_employees_active'] as int,
      participationRateThisWeek: (json['participation_rate_this_week'] as num).toDouble(),
      totalStepsThisWeek: json['total_steps_this_week'] as int,
      totalKmThisWeek: (json['total_km_this_week'] as num).toDouble(),
      periodStart: period['start'] as String,
      periodEnd: period['end'] as String,
    );
  }
}

/// One row of GET /api/monitoring/per-divisi's response — already ranked
/// by the backend (highest avg_points first).
class DivisionMonitoringEntry {
  final int rank;
  final int divisionId;
  final String divisionName;
  final int employeeCount;
  final double avgPoints;
  final int avgSteps;

  const DivisionMonitoringEntry({
    required this.rank,
    required this.divisionId,
    required this.divisionName,
    required this.employeeCount,
    required this.avgPoints,
    required this.avgSteps,
  });

  factory DivisionMonitoringEntry.fromJson(Map<String, dynamic> json) {
    return DivisionMonitoringEntry(
      rank: json['rank'] as int,
      divisionId: json['division_id'] as int,
      divisionName: json['division_name'] as String,
      employeeCount: json['employee_count'] as int,
      avgPoints: (json['avg_points'] as num).toDouble(),
      avgSteps: json['avg_steps'] as int,
    );
  }
}

/// One row of GET /api/monitoring/employees's response — the "Progres
/// Karyawan" list on MonitoringScreen.
class EmployeeListItem {
  final int id;
  final String fullName;
  final String? employeeCode;
  final String? photoUrl;
  final String divisionName;
  final int totalPoints;
  final int stepsThisWeek;
  final int currentStreakDays;
  final bool isActiveRecently;

  const EmployeeListItem({
    required this.id,
    required this.fullName,
    this.employeeCode,
    this.photoUrl,
    required this.divisionName,
    required this.totalPoints,
    required this.stepsThisWeek,
    required this.currentStreakDays,
    required this.isActiveRecently,
  });

  factory EmployeeListItem.fromJson(Map<String, dynamic> json) {
    return EmployeeListItem(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      employeeCode: json['employee_code'] as String?,
      photoUrl: _photoUrlOf(json),
      divisionName: json['division_name'] as String,
      totalPoints: json['total_points'] as int,
      stepsThisWeek: json['steps_this_week'] as int,
      currentStreakDays: json['current_streak_days'] as int,
      isActiveRecently: json['is_active_recently'] as bool,
    );
  }
}

/// How the "Progres Karyawan" list is sorted — mirrors the backend's
/// sort_by query values exactly (see MONITORING_API.md).
enum EmployeeSortBy {
  poin('poin', 'Poin'),
  langkahMingguIni('langkah_minggu_ini', 'Langkah'),
  nama('nama', 'Nama'),
  divisi('divisi', 'Divisi');

  final String apiValue;
  final String label;
  const EmployeeSortBy(this.apiValue, this.label);
}

/// One row of GET /api/monitoring/employees/{id}'s point_breakdown.
class PointBreakdownEntry {
  final String ruleCode;
  final String ruleName;
  final int totalPoints;
  final int timesAwarded;

  const PointBreakdownEntry({
    required this.ruleCode,
    required this.ruleName,
    required this.totalPoints,
    required this.timesAwarded,
  });

  factory PointBreakdownEntry.fromJson(Map<String, dynamic> json) {
    return PointBreakdownEntry(
      ruleCode: json['rule_code'] as String,
      ruleName: json['rule_name'] as String,
      totalPoints: json['total_points'] as int,
      timesAwarded: json['times_awarded'] as int,
    );
  }
}

/// Mirrors GET /api/monitoring/employees/{id}'s response — reuses
/// ActivityHistoryEntry and WalkSession, whose JSON shapes are identical to
/// what this endpoint returns (see ActivityHistoryService::weekly() on the
/// backend, which this endpoint calls directly rather than duplicating).
class EmployeeMonitoringDetail {
  final int id;
  final String fullName;
  final String? employeeCode;
  final String? photoUrl;
  final String? divisionName;
  final String? roleName;
  final String? positionTitle;
  final int totalPoints;
  final int currentStreakDays;
  final int averageDailySteps;
  final List<ActivityHistoryEntry> weeklyHistory;
  final List<WalkSession> walkSessions;
  final List<PointBreakdownEntry> pointBreakdown;

  const EmployeeMonitoringDetail({
    required this.id,
    required this.fullName,
    this.employeeCode,
    this.photoUrl,
    this.divisionName,
    this.roleName,
    this.positionTitle,
    required this.totalPoints,
    required this.currentStreakDays,
    required this.averageDailySteps,
    required this.weeklyHistory,
    required this.walkSessions,
    required this.pointBreakdown,
  });

  factory EmployeeMonitoringDetail.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>;
    return EmployeeMonitoringDetail(
      id: employee['id'] as int,
      fullName: employee['full_name'] as String,
      employeeCode: employee['employee_code'] as String?,
      photoUrl: _photoUrlOf(employee),
      divisionName: employee['division_name'] as String?,
      roleName: employee['role_name'] as String?,
      positionTitle: employee['position_title'] as String?,
      totalPoints: json['total_points'] as int,
      currentStreakDays: json['current_streak_days'] as int,
      averageDailySteps: json['average_daily_steps'] as int,
      weeklyHistory: (json['weekly_history'] as List)
          .map((e) => ActivityHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      walkSessions: (json['walk_sessions'] as List)
          .map((e) => WalkSession.fromJson(e as Map<String, dynamic>))
          .toList(),
      pointBreakdown: (json['point_breakdown'] as List)
          .map((e) => PointBreakdownEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      // badges intentionally omitted — always [] server-side for now (see
      // MONITORING_API.md); nothing here needs it yet.
    );
  }
}

/// One row of GET /api/monitoring/tidak-aktif's response.
/// [lastActivityDate] is null when the employee has never logged any
/// activity at all, not just "none in the last N days".
class InactiveEmployee {
  final int id;
  final String fullName;
  final String? employeeCode;
  final String? photoUrl;
  final String divisionName;
  final String? lastActivityDate;

  const InactiveEmployee({
    required this.id,
    required this.fullName,
    this.employeeCode,
    this.photoUrl,
    required this.divisionName,
    this.lastActivityDate,
  });

  factory InactiveEmployee.fromJson(Map<String, dynamic> json) {
    return InactiveEmployee(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      employeeCode: json['employee_code'] as String?,
      photoUrl: _photoUrlOf(json),
      divisionName: json['division_name'] as String,
      lastActivityDate: json['last_activity_date'] as String?,
    );
  }
}
