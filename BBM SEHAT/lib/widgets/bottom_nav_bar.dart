import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../state/employee_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class BbmBottomNavBar extends StatelessWidget {
  const BbmBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // MANAGEMENT/SUPER_ADMIN/ADMIN_UMUM_SDM get a 5th tab; everyone else's
    // bar is byte-for-byte the same 4-tab layout as before this feature —
    // Employee.canAccessMonitoring mirrors the backend's own role gate on
    // /api/monitoring/* (see MONITORING_API.md), so this is a UI
    // convenience, not the real access control.
    final canAccessMonitoring = context.watch<EmployeeState>().employee?.canAccessMonitoring ?? false;
    return Container(
      height: 78 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(
        left: 8, right: 8, bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(children: [
        _NavItem(
          icon: Icons.home_outlined,
          label: 'Beranda',
          active: state.screen == AppScreen.beranda,
          onTap: () => state.go(AppScreen.beranda),
        ),
        _NavItem(
          icon: Icons.bar_chart_rounded,
          label: 'Riwayat',
          active: state.screen == AppScreen.riwayat,
          onTap: () => state.go(AppScreen.riwayat),
        ),
        SizedBox(
          width: 66,
          child: Center(
            child: GestureDetector(
              onTap: () => state.go(AppScreen.jalan),
              child: Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.only(top: 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                  border: Border.all(color: AppColors.bg, width: 4),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.directions_walk, color: Color(0xFF06231A), size: 25),
              ),
            ),
          ),
        ),
        _NavItem(
          icon: Icons.emoji_events_outlined,
          label: 'Peringkat',
          active: state.screen == AppScreen.papan,
          onTap: () => state.go(AppScreen.papan),
        ),
        _NavItem(
          icon: Icons.person_outline,
          label: 'Profil',
          active: state.screen == AppScreen.profil,
          onTap: () => state.go(AppScreen.profil),
        ),
        if (canAccessMonitoring)
          _NavItem(
            icon: Icons.insights,
            label: 'Monitoring',
            active: state.screen == AppScreen.monitoring,
            onTap: () => state.go(AppScreen.monitoring),
          ),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.mut;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.accentTint : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 10, weight: FontWeight.w600, color: color),
            ),
          ]),
        ),
      ),
    );
  }
}
