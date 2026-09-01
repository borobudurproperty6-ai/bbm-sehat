import 'package:flutter/material.dart';
import '../models/activity_history.dart';
import '../services/activity_service.dart';

/// The logged-in employee's step history (GET /api/activity/history) for
/// the Riwayat screen's chart — re-fetched whenever the Mingguan/Bulanan
/// toggle changes.
class HistoryState extends ChangeNotifier {
  ActivityHistory? history;
  bool isLoading = false;
  String? error;
  bool sessionExpired = false;

  Future<void> fetch(HistoryPeriod period) async {
    isLoading = true;
    error = null;
    sessionExpired = false;
    notifyListeners();

    final result = await ActivityService.instance.fetchHistory(period);

    isLoading = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.history != null) {
      history = result.history;
    } else {
      history = null;
      error = result.errorMessage ?? 'Gagal memuat riwayat aktivitas.';
    }
    notifyListeners();
  }

  void clear() {
    history = null;
    isLoading = false;
    error = null;
    sessionExpired = false;
    notifyListeners();
  }
}
