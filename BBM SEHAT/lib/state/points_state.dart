import 'package:flutter/material.dart';
import '../services/points_service.dart';

/// The logged-in employee's points (GET /api/points/summary) — total
/// earned, today's total, and the current rolling workday streak. Fetched
/// independently by both Beranda and Profil, since either can be the first
/// screen opened after login.
class PointsState extends ChangeNotifier {
  int totalPoints = 0;
  int pointsToday = 0;
  int currentStreakDays = 0;
  bool isLoading = false;
  String? error;
  bool sessionExpired = false;

  Future<void> fetchSummary() async {
    isLoading = true;
    error = null;
    sessionExpired = false;
    notifyListeners();

    final result = await PointsService.instance.fetchSummary();

    isLoading = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.summary != null) {
      totalPoints = result.summary!.totalPoints;
      pointsToday = result.summary!.pointsToday;
      currentStreakDays = result.summary!.currentStreakDays;
    } else {
      // Failed to load — show 0s rather than stale data or a crash.
      totalPoints = 0;
      pointsToday = 0;
      currentStreakDays = 0;
      error = result.errorMessage ?? 'Gagal memuat data poin.';
    }
    notifyListeners();
  }

  void clear() {
    totalPoints = 0;
    pointsToday = 0;
    currentStreakDays = 0;
    isLoading = false;
    error = null;
    sessionExpired = false;
    notifyListeners();
  }
}
