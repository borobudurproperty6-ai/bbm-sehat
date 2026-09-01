import '../config/api_config.dart';

/// Mirrors the backend's EmployeeResource JSON shape (GET /api/me,
/// POST /api/login's "employee" field, etc.) — the real, logged-in
/// employee, as opposed to the mock display data other screens still use.
class Employee {
  final int id;
  final String? employeeCode;
  final String fullName;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? positionTitle;
  final String? divisionName;
  final String? divisionCode;
  final String? roleName;
  final String? roleCode;
  final bool isManagement;

  /// Account/login-access status: 'active', 'inactive', or 'archived'
  /// (resigned employee, history kept). Distinct from activity status
  /// (has this employee been exercising lately) — see MonitoringController.
  final String accountStatus;
  final bool mustChangePassword;

  const Employee({
    required this.id,
    required this.fullName,
    this.employeeCode,
    this.email,
    this.phone,
    this.photoUrl,
    this.positionTitle,
    this.divisionName,
    this.divisionCode,
    this.roleName,
    this.roleCode,
    this.isManagement = false,
    this.accountStatus = 'active',
    this.mustChangePassword = false,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final division = json['division'] as Map<String, dynamic>?;
    final role = json['role'] as Map<String, dynamic>?;

    return Employee(
      id: json['id'] as int,
      employeeCode: json['employee_code'] as String?,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: (json['photo_url'] as String?) != null
          ? ApiConfig.resolveAssetUrl(json['photo_url'] as String)
          : null,
      positionTitle: json['position_title'] as String?,
      divisionName: division?['name'] as String?,
      divisionCode: division?['code'] as String?,
      roleName: role?['name'] as String?,
      roleCode: role?['code'] as String?,
      isManagement: json['is_management'] as bool? ?? false,
      accountStatus: json['account_status'] as String? ?? 'active',
      mustChangePassword: json['must_change_password'] as bool? ?? false,
    );
  }

  /// Mirrors the backend's monitoring role gate exactly (see
  /// MONITORING_API.md / routes/api.php's 'role:management,super_admin,
  /// admin_umum_sdm' middleware on /api/monitoring/*) — division_admin is
  /// deliberately excluded, its scope is one division, not the whole
  /// company. Keep this list in sync with the backend if that ever changes.
  static const _monitoringRoleCodes = ['MANAGEMENT', 'SUPER_ADMIN', 'ADMIN_UMUM_SDM'];

  bool get canAccessMonitoring => _monitoringRoleCodes.contains(roleCode?.toUpperCase());

  /// First letters of up to the first two words of the name, e.g.
  /// "Andi Pratama" -> "AP". Falls back to "?" for an empty name.
  String get initials {
    final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters;
  }
}
