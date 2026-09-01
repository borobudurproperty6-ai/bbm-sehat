import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../state/employee_state.dart';
import '../state/walk_session_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/glow_route_map.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final walk = context.watch<WalkSessionState>();
    final employee = context.watch<EmployeeState>().employee;
    final session = walk.lastFinishedSession;
    final dateLabel = DateFormat("d MMM yyyy · HH.mm", 'id_ID').format(session?.endedAt ?? DateTime.now());

    final distanceKm = ((session?.distanceMeters ?? 0) / 1000).toStringAsFixed(2).replaceAll('.', ',');
    final durationSeconds = session?.durationSeconds ?? walk.elapsedSeconds;
    final durationFormatted =
        '${(durationSeconds ~/ 60).toString().padLeft(2, '0')}:${(durationSeconds % 60).toString().padLeft(2, '0')}';
    final pointsAwarded = session?.pointsAwarded ?? 0;

    Future<void> save() async {
      walk.reset();
      appState.go(AppScreen.beranda);
    }

    Future<void> discard() async {
      await walk.discardAndReset();
      appState.go(AppScreen.beranda);
    }

    return Container(
      color: AppColors.bg,
      child: Column(children: [
        SizedBox(
          height: 322,
          child: Stack(children: [
            Positioned.fill(
              // Amber, not the mint-green of an in-progress route — a
              // saved/completed session reads visually distinct from one
              // still being recorded.
              child: GlowRouteMap(points: walk.points, routeColor: AppColors.amber),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 34, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.bg.withValues(alpha: 0.9), Colors.transparent],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.celebration, size: 13, color: Color(0xFF06231A)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('Sesi selesai — kerja bagus!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 11, weight: FontWeight.w600, color: const Color(0xFF06231A))),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sesi Jalan Kaki Selesai', style: AppText.heading(size: 25)),
              const SizedBox(height: 3),
              Text('$dateLabel · Divisi ${employee?.divisionName ?? '—'}',
                  style: AppText.body(size: 12.5, color: AppColors.mut)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.only(bottom: 18),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                child: Row(children: [
                  _big(distanceKm, 'Kilometer', AppColors.accent),
                  const SizedBox(width: 26),
                  _big(durationFormatted, 'Durasi', AppColors.text),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                child: Row(children: [
                  _mid('${walk.liveSteps}', 'Langkah', AppColors.sky),
                  _mid('+$pointsAwarded', 'Poin sesi', AppColors.violet),
                ]),
              ),
              // Badge/Lencana system is a separate future session — stays
              // mock for now, unchanged.
              Container(
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.amberTint,
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.32)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amber, width: 1.5),
                    ),
                    child: const Icon(Icons.bolt, size: 26, color: AppColors.amber),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('LENCANA BARU!',
                          style: AppText.body(size: 10, color: AppColors.amberSoft).copyWith(letterSpacing: 1.2)),
                      Text('Pejalan 10K', style: AppText.heading(size: 17)),
                      Text('Kamu menembus 10.000 langkah hari ini.',
                          style: AppText.body(size: 11.5, color: AppColors.mut)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: discard,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.line),
                      foregroundColor: AppColors.mut,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Text('Hapus', style: AppText.heading(size: 15, color: AppColors.mut)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.route,
                        foregroundColor: const Color(0xFF06231A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check),
                      label: Text('Simpan Sesi', style: AppText.heading(size: 16, color: const Color(0xFF06231A))),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _big(String value, String label, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.num(size: 46, color: color)),
          ),
          const SizedBox(height: 7),
          Text(label.toUpperCase(), style: AppText.body(size: 11, color: AppColors.mut).copyWith(letterSpacing: 0.8)),
        ]),
      );

  Widget _mid(String value, String label, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppText.num(size: 30, color: color)),
          const SizedBox(height: 7),
          Text(label.toUpperCase(), style: AppText.body(size: 11, color: AppColors.mut).copyWith(letterSpacing: 0.8)),
        ]),
      );
}
