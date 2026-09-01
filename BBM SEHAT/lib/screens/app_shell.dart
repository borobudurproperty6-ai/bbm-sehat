import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../state/employee_state.dart';
import '../state/walk_session_state.dart';
import '../theme/colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'badge_screen.dart';
import 'beranda_screen.dart';
import 'employee_detail_screen.dart';
import 'jalan_kaki_screen.dart';
import 'monitoring_screen.dart';
import 'papan_peringkat_screen.dart';
import 'profil_screen.dart';
import 'riwayat_screen.dart';
import 'session_summary_screen.dart';

/// Hosts the logged-in app: the current screen (with a bottom nav) or the
/// full-bleed walk-session summary shown right after finishing a walk.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    // AppShell is mounted exactly once per logged-in session (login success
    // or a restored session both land here), so this is the one place that
    // guarantees Beranda's greeting has real employee data even if the user
    // never visits Profil first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeState>().fetchIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final walkSession = context.watch<WalkSessionState>();
    final showingSummary = walkSession.status == WalkTrackingStatus.done;
    final walkActive =
        walkSession.status == WalkTrackingStatus.running || walkSession.status == WalkTrackingStatus.paused;

    Widget body;
    if (showingSummary) {
      body = const SessionSummaryScreen();
    } else {
      body = switch (state.screen) {
        AppScreen.beranda => const BerandaScreen(),
        AppScreen.riwayat => const RiwayatScreen(),
        AppScreen.jalan => const JalanKakiScreen(),
        AppScreen.papan => const PapanPeringkatScreen(),
        AppScreen.badge => const BadgeScreen(),
        AppScreen.profil => const ProfilScreen(),
        AppScreen.monitoring => const MonitoringScreen(),
        AppScreen.employeeDetail => const EmployeeDetailScreen(),
      };
    }

    // Employee Detail and Badge both have their own on-screen back arrow
    // that navigates to a specific parent screen (Monitoring / Profil)
    // rather than just "the previous screen" — without this, the system
    // back gesture bypasses that and exits the app instead, which is
    // jarring on a sub-screen that visibly offers its own way back.
    final hasOwnBackTarget =
        !showingSummary && (state.screen == AppScreen.employeeDetail || state.screen == AppScreen.badge);

    return PopScope(
      canPop: !hasOwnBackTarget,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (state.screen == AppScreen.employeeDetail) {
          state.closeEmployeeDetail();
        } else if (state.screen == AppScreen.badge) {
          state.go(AppScreen.profil);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(key: ValueKey(showingSummary ? 'summary' : state.screen), child: body),
          ),
        ),
        bottomNavigationBar: state.showNav(walkActive: walkActive, showingSummary: showingSummary)
            ? const BbmBottomNavBar()
            : null,
      ),
    );
  }
}
