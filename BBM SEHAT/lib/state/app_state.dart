import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

enum AppFlow { splash, login, changePassword, app }
enum AppScreen { beranda, riwayat, jalan, papan, badge, profil, monitoring, employeeDetail }
enum HistRange { minggu, bulan }
enum PapanTab { divisi, semua, perusahaan }

class AppState extends ChangeNotifier {
  AppFlow flow = AppFlow.splash;
  AppScreen screen = AppScreen.beranda;

  bool obscurePassword = true;
  bool rememberMe = true;

  bool isLoggingIn = false;
  String? loginError;

  bool isChangingPassword = false;
  String? changePasswordError;

  // The password just used to log in — kept only in memory, needed because
  // POST /api/change-password requires current_password and this flow
  // (mandatory change on first login) deliberately doesn't show that field
  // again to the user, since they just typed it on the login screen.
  String? _pendingCurrentPassword;

  HistRange histRange = HistRange.minggu;
  PapanTab papanTab = PapanTab.divisi;

  int? openBadgeId;

  Timer? _bootTimer;
  bool _disposed = false;

  AppState() {
    _bootTimer = Timer(const Duration(milliseconds: 1700), () async {
      if (flow != AppFlow.splash) return;

      final hasSession = await AuthService.instance.hasValidSession();
      if (_disposed) return;

      flow = hasSession ? AppFlow.app : AppFlow.login;
      if (hasSession) {
        _initializeFcm();
        _applyPendingNotificationScreen();
      }
      notifyListeners();
    });
  }

  /// Fire-and-forget — FCM setup shows a native permission dialog that can
  /// sit unanswered indefinitely, so it must never block the app-entry
  /// transition (login button spinner, splash timer) that's already in
  /// flight when this is called.
  void _initializeFcm() {
    unawaited(FCMService.instance.initialize(onNotificationTap: _handleNotificationTap));
  }

  /// A tapped notification's target screen — e.g. a walk reminder tapped
  /// while the app was still on the splash/login screen (cold-started from
  /// terminated by the tap itself). Remembered here until [flow] actually
  /// reaches AppFlow.app, since AppScreen navigation is meaningless before
  /// then (AppShell, where it applies, isn't even built yet).
  AppScreen? _pendingNotificationScreen;

  void _applyPendingNotificationScreen() {
    final target = _pendingNotificationScreen;
    if (target == null) return;
    _pendingNotificationScreen = null;
    screen = target;
  }

  /// Called by FCMService whenever a notification is tapped, in any of the
  /// 3 states (foreground/background/terminated) — [notificationType]
  /// mirrors the backend's push 'type' data field. Unrecognized types
  /// (including plain null, e.g. a notification sent without that field)
  /// default to Beranda rather than leaving whatever screen was already
  /// showing.
  void _handleNotificationTap(String? notificationType) {
    final target = notificationType == 'walk_reminder' ? AppScreen.jalan : AppScreen.beranda;

    if (flow == AppFlow.app) {
      screen = target;
      notifyListeners();
    } else {
      _pendingNotificationScreen = target;
    }
  }

  String get greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  Future<void> login(String employeeCode, String password) async {
    if (isLoggingIn) return;

    isLoggingIn = true;
    loginError = null;
    notifyListeners();

    final result = await AuthService.instance.login(employeeCode.trim(), password);
    if (_disposed) return;

    isLoggingIn = false;
    if (result.success) {
      _pendingCurrentPassword = password;
      flow = result.mustChangePassword ? AppFlow.changePassword : AppFlow.app;
      if (flow == AppFlow.app) {
        _initializeFcm();
        _applyPendingNotificationScreen();
      }
    } else {
      loginError = result.errorMessage;
    }
    notifyListeners();
  }

  Future<void> submitNewPassword(String newPassword) async {
    if (isChangingPassword) return;

    isChangingPassword = true;
    changePasswordError = null;
    notifyListeners();

    final error = await AuthService.instance.changePassword(
      currentPassword: _pendingCurrentPassword ?? '',
      newPassword: newPassword,
    );
    if (_disposed) return;

    isChangingPassword = false;
    if (error == null) {
      _pendingCurrentPassword = null;
      flow = AppFlow.app;
      _initializeFcm();
      _applyPendingNotificationScreen();
    } else {
      changePasswordError = error;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    // A stale target queued but never applied (e.g. session expired before
    // ever reaching AppFlow.app) must not carry over and misdirect whoever
    // logs in next on this device.
    _pendingNotificationScreen = null;
    flow = AppFlow.login;
    screen = AppScreen.beranda;
    loginError = null;
    notifyListeners();

    await AuthService.instance.logout();
  }

  void go(AppScreen s) {
    screen = s;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void toggleRemember() {
    rememberMe = !rememberMe;
    notifyListeners();
  }

  void setHistRange(HistRange r) {
    histRange = r;
    notifyListeners();
  }

  void setPapanTab(PapanTab t) {
    papanTab = t;
    notifyListeners();
  }

  void openBadge(int id) {
    openBadgeId = id;
    notifyListeners();
  }

  void closeBadge() {
    openBadgeId = null;
    notifyListeners();
  }

  /// Which employee's detail is open in MonitoringScreen's "Progres
  /// Karyawan" list — same single-parameterized-screen pattern as
  /// openBadgeId above. Set alongside the AppScreen.employeeDetail
  /// navigation, not independently, so the two never disagree about
  /// whether a detail screen should be showing.
  int? monitoringEmployeeId;

  void openEmployeeDetail(int employeeId) {
    monitoringEmployeeId = employeeId;
    screen = AppScreen.employeeDetail;
    notifyListeners();
  }

  void closeEmployeeDetail() {
    monitoringEmployeeId = null;
    screen = AppScreen.monitoring;
    notifyListeners();
  }

  /// Walk-session tracking now lives in WalkSessionState (real GPS, not a
  /// fake timer) — this just folds its status into the same nav-visibility
  /// rule the old single-state version had: no bottom nav while a walk is
  /// actively running/paused, or while its just-finished summary is shown.
  bool showNav({required bool walkActive, required bool showingSummary}) =>
      flow == AppFlow.app && !(screen == AppScreen.jalan && walkActive) && !showingSummary;

  @override
  void dispose() {
    _disposed = true;
    _bootTimer?.cancel();
    super.dispose();
  }
}
