import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../state/walk_session_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/glow_route_map.dart';
import '../widgets/route_map.dart';

class JalanKakiScreen extends StatelessWidget {
  const JalanKakiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final walk = context.watch<WalkSessionState>();
    final active = walk.status == WalkTrackingStatus.running || walk.status == WalkTrackingStatus.paused;

    return Column(children: [
      Expanded(
        child: Stack(children: [
          Positioned.fill(
            child: active
                ? GlowRouteMap(points: walk.points, routeColor: AppColors.accent, live: true)
                // Before a session starts there's no real route yet — keep
                // the old stylized placeholder rather than an empty map.
                : const RouteMap(variant: RouteVariant.live, progress: 0),
          ),
          Positioned(
            top: 12, left: 16, right: 16,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(
                onTap: () => appState.go(AppScreen.beranda),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.line),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: AppColors.text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.satellite_alt, size: 14, color: AppColors.route),
                  const SizedBox(width: 6),
                  Text(active ? 'GPS akurat' : 'GPS siap', style: AppText.body(size: 12, color: AppColors.route)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      if (walk.status == WalkTrackingStatus.idle) _IdleSheet(walk: walk),
      if (active) _TrackingSheet(walk: walk),
    ]);
  }
}

class _IdleSheet extends StatelessWidget {
  final WalkSessionState walk;
  const _IdleSheet({required this.walk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(children: [
        Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Siap jalan kaki?', style: AppText.heading(size: 20)),
        const SizedBox(height: 4),
        Text(
          walk.permissionDenied && walk.error != null
              ? walk.error!
              : 'Aplikasi akan meminta izin lokasi untuk merekam rute — GPS hanya aktif selama sesi ini berjalan, dan berhenti saat kamu menekan Selesai.',
          textAlign: TextAlign.center,
          style: AppText.body(size: 13, color: walk.permissionDenied ? AppColors.amber : AppColors.mut),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: walk.isStarting ? null : walk.start,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.route,
              foregroundColor: const Color(0xFF06231A),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: walk.isStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06231A)),
                  )
                : const Icon(Icons.play_arrow),
            label: Text('Mulai Rekam', style: AppText.heading(size: 18, color: const Color(0xFF06231A))),
          ),
        ),
      ]),
    );
  }
}

class _TrackingSheet extends StatelessWidget {
  final WalkSessionState walk;
  const _TrackingSheet({required this.walk});

  @override
  Widget build(BuildContext context) {
    final paused = walk.status == WalkTrackingStatus.paused;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(children: [
        Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        if (paused) ...[
          Text('● DIJEDA',
              style: AppText.body(size: 11, color: AppColors.amber).copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 12),
        ],
        Row(children: [
          _stat(walk.elapsedFormatted, 'Waktu', AppColors.text),
          _divider(),
          _stat(walk.distanceKmFormatted, 'Kilometer', AppColors.accent),
          _divider(),
          _stat('${walk.liveSteps}', 'Langkah', AppColors.text),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          GestureDetector(
            onTap: walk.togglePause,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.card2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(paused ? Icons.play_arrow : Icons.pause, color: AppColors.text, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed: walk.isFinishing ? null : walk.finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.route,
                  foregroundColor: const Color(0xFF06231A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: walk.isFinishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06231A)),
                      )
                    : const Icon(Icons.flag),
                label: Text('Selesai', style: AppText.heading(size: 18, color: const Color(0xFF06231A))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: AppText.num(size: 32, color: color)),
          const SizedBox(height: 7),
          Text(label.toUpperCase(),
              style: AppText.body(size: 10, color: AppColors.mut).copyWith(letterSpacing: 1)),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 40, color: AppColors.line);
}
