import 'package:flutter/material.dart';
import '../models/leaderboard_my_position.dart';
import '../models/models.dart';
import '../services/leaderboard_service.dart';

/// Two independent slices of the same feature: the full ranked list (Papan
/// Peringkat screen, re-fetched whenever its scope tab changes) and the
/// logged-in employee's own position (Beranda's summary card, always
/// own_division/weekly).
class LeaderboardState extends ChangeNotifier {
  List<LeaderboardEntry> entries = [];
  bool isLoadingEntries = false;
  String? entriesError;
  bool entriesSessionExpired = false;

  LeaderboardMyPosition? myPosition;
  bool isLoadingMyPosition = false;
  String? myPositionError;
  bool myPositionSessionExpired = false;

  Future<void> fetchEntries({
    required LeaderboardScope scope,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    isLoadingEntries = true;
    entriesError = null;
    entriesSessionExpired = false;
    notifyListeners();

    final result = await LeaderboardService.instance.fetchLeaderboard(scope: scope, period: period);

    isLoadingEntries = false;
    if (result.unauthorized) {
      entriesSessionExpired = true;
    } else if (result.entries != null) {
      entries = result.entries!;
    } else {
      entries = [];
      entriesError = result.errorMessage ?? 'Gagal memuat papan peringkat.';
    }
    notifyListeners();
  }

  Future<void> fetchMyPosition({
    LeaderboardScope scope = LeaderboardScope.ownDivision,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    isLoadingMyPosition = true;
    myPositionError = null;
    myPositionSessionExpired = false;
    notifyListeners();

    final result = await LeaderboardService.instance.fetchMyPosition(scope: scope, period: period);

    isLoadingMyPosition = false;
    if (result.unauthorized) {
      myPositionSessionExpired = true;
    } else if (result.position != null) {
      myPosition = result.position;
    } else {
      myPosition = null;
      myPositionError = result.errorMessage ?? 'Gagal memuat posisi peringkat.';
    }
    notifyListeners();
  }

  void clear() {
    entries = [];
    isLoadingEntries = false;
    entriesError = null;
    entriesSessionExpired = false;
    myPosition = null;
    isLoadingMyPosition = false;
    myPositionError = null;
    myPositionSessionExpired = false;
    notifyListeners();
  }
}
