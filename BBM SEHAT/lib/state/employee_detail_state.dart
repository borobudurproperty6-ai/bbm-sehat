import 'package:flutter/material.dart';
import '../models/monitoring.dart';
import '../services/monitoring_service.dart';

/// One employee's full monitoring detail (GET /api/monitoring/employees/{id})
/// — deliberately its own class rather than folded into MonitoringState:
/// this has a per-employee-view lifecycle (opened/closed repeatedly for
/// different employees from the "Progres Karyawan" list) distinct from the
/// dashboard-wide data MonitoringState holds.
class EmployeeDetailState extends ChangeNotifier {
  EmployeeMonitoringDetail? detail;
  bool isLoading = false;
  String? error;
  bool sessionExpired = false;
  bool forbidden = false;
  bool notFound = false;

  Future<void> fetch(int employeeId) async {
    isLoading = true;
    error = null;
    forbidden = false;
    notFound = false;
    notifyListeners();

    final result = await MonitoringService.instance.fetchEmployeeDetail(employeeId);

    isLoading = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.forbidden) {
      forbidden = true;
    } else if (result.notFound) {
      notFound = true;
    } else if (result.detail != null) {
      detail = result.detail;
    } else {
      error = result.errorMessage ?? 'Gagal memuat detail karyawan.';
    }
    notifyListeners();
  }

  void clear() {
    detail = null;
    isLoading = false;
    error = null;
    sessionExpired = false;
    forbidden = false;
    notFound = false;
    notifyListeners();
  }
}
