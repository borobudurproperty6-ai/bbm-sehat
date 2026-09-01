import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/auth_service.dart';

/// Holds the real, logged-in employee's data (GET /api/me), shared across
/// screens via Provider so it's fetched once per need rather than
/// re-implemented per screen. Beranda reads name/division from it too, but
/// always via [fetchIfNeeded] rather than forcing a fresh fetch on every
/// visit like Profil does.
class EmployeeState extends ChangeNotifier {
  Employee? employee;
  bool isLoading = false;
  String? error;
  bool sessionExpired = false;

  /// Fetches only if nothing is loaded/in flight yet — for screens (like
  /// Beranda) that just need the data to exist, not a guaranteed-fresh copy
  /// on every visit.
  Future<void> fetchIfNeeded() async {
    if (employee != null || isLoading) return;
    await fetchMe();
  }

  Future<void> fetchMe() async {
    isLoading = true;
    employee = null;
    error = null;
    sessionExpired = false;
    notifyListeners();

    final result = await AuthService.instance.fetchMe();

    isLoading = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.employee != null) {
      employee = result.employee;
    } else {
      error = result.errorMessage ?? 'Gagal memuat data profil.';
    }
    notifyListeners();
  }

  void clear() {
    employee = null;
    isLoading = false;
    error = null;
    sessionExpired = false;
    notifyListeners();
  }
}
