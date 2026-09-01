import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monitoring.dart';
import '../models/walk_session.dart';
import '../state/app_state.dart';
import '../state/employee_detail_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/common.dart';

/// Full progress detail for one employee, opened by tapping a card in
/// MonitoringScreen's "Progres Karyawan" list. Deliberately a separate
/// screen/file from RiwayatScreen (which shows the logged-in employee their
/// own data) even though the visual language matches — riwayat_screen.dart
/// is untouched by this feature per the task's own instruction, and the
/// backend data source is different (GET /api/monitoring/employees/{id},
/// not /api/activity/history + /api/walk-sessions).
class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final employeeId = context.read<AppState>().monitoringEmployeeId;
    if (employeeId == null) return; // shouldn't happen — openEmployeeDetail always sets both together
    await context.read<EmployeeDetailState>().fetch(employeeId);
    if (!mounted) return;
    if (context.read<EmployeeDetailState>().sessionExpired) {
      context.read<EmployeeDetailState>().clear();
      context.read<AppState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final state = context.watch<EmployeeDetailState>();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: Row(children: [
          GestureDetector(
            onTap: appState.closeEmployeeDetail,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.line),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_left, color: AppColors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Detail Karyawan', style: AppText.heading(size: 18)),
          ),
        ]),
      ),
      Expanded(
        child: state.isLoading && state.detail == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : state.notFound
                ? const _StatusNotice(icon: Icons.person_off_outlined, message: 'Karyawan tidak ditemukan.')
                : state.forbidden
                    ? const _StatusNotice(
                        icon: Icons.lock_outline, message: 'Anda tidak memiliki akses ke halaman ini.')
                    : state.detail == null && state.error != null
                        ? _StatusNotice(icon: Icons.wifi_off_rounded, message: state.error!, onRetry: _load)
                        : state.detail == null
                            ? const SizedBox.shrink()
                            : _DetailBody(detail: state.detail!),
      ),
    ]);
  }
}

class _StatusNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  const _StatusNotice({required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 32, color: AppColors.mut),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppColors.mut)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text('Coba lagi', style: AppText.body(size: 13, color: AppColors.accent)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final EmployeeMonitoringDetail detail;
  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final maxSteps =
        detail.weeklyHistory.isEmpty ? 0 : detail.weeklyHistory.map((e) => e.steps).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(
              initials: _initialsOf(detail.fullName),
              imageUrl: detail.photoUrl,
              size: 56,
              fontSize: 20,
              borderColor: AppColors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(detail.fullName, style: AppText.heading(size: 19)),
              const SizedBox(height: 2),
              Text(
                '${detail.divisionName ?? '—'} · ${detail.employeeCode ?? '—'}',
                style: AppText.body(size: 12, color: AppColors.mut),
              ),
              if (detail.positionTitle != null)
                Text(detail.positionTitle!, style: AppText.body(size: 11.5, color: AppColors.mut)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            _statCell('${detail.totalPoints}', 'Total poin', AppColors.violet, border: true),
            _statCell('${detail.currentStreakDays}', 'Hari beruntun', AppColors.amberSoft, border: true),
            _statCell('${detail.averageDailySteps}', 'Rata² langkah', AppColors.accent, border: false),
          ]),
        ),
        const SectionLabel('Langkah Minggu Ini'),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in detail.weeklyHistory)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Container(
                          height: 100 * (maxSteps > 0 ? e.steps / maxSteps : 0.0),
                          decoration: BoxDecoration(
                            color: e.targetMet == true ? AppColors.amber : AppColors.accent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                              bottomLeft: Radius.circular(3),
                              bottomRight: Radius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(e.label, style: AppText.body(size: 10, color: AppColors.mut)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SectionLabel('Sesi Jalan Kaki'),
        if (detail.walkSessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child:
                Text('Belum ada sesi jalan kaki tersimpan.', style: AppText.body(size: 12.5, color: AppColors.mut)),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              for (var i = 0; i < detail.walkSessions.length; i++)
                _WalkSessionRow(
                  session: detail.walkSessions[i],
                  isLast: i == detail.walkSessions.length - 1,
                ),
            ]),
          ),
        const SectionLabel('Rincian Poin'),
        if (detail.pointBreakdown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Belum ada poin tercatat.', style: AppText.body(size: 12.5, color: AppColors.mut)),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              for (var i = 0; i < detail.pointBreakdown.length; i++)
                _PointBreakdownRow(
                  entry: detail.pointBreakdown[i],
                  isLast: i == detail.pointBreakdown.length - 1,
                ),
            ]),
          ),
        const SectionLabel('Lencana'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Belum ada lencana — fitur penetapan lencana menyusul.',
            style: AppText.body(size: 12.5, color: AppColors.mut),
          ),
        ),
      ]),
    );
  }

  Widget _statCell(String value, String label, Color color, {required bool border}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            border: border ? const Border(right: BorderSide(color: AppColors.line)) : null,
          ),
          child: Column(children: [
            Text(value, style: AppText.num(size: 20, color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppText.body(size: 10, color: AppColors.mut), textAlign: TextAlign.center),
          ]),
        ),
      );

  static String _initialsOf(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

class _WalkSessionRow extends StatelessWidget {
  final WalkSession session;
  final bool isLast;
  const _WalkSessionRow({required this.session, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final startedAt = session.startedAt;
    final distanceKm = ((session.distanceMeters ?? 0) / 1000).toStringAsFixed(1).replaceAll('.', ',');
    final minutes = ((session.durationSeconds ?? 0) / 60).round();
    final points = session.pointsAwarded ?? 0;
    final dateLabel = '${startedAt.day}/${startedAt.month}/${startedAt.year} · '
        '${startedAt.hour.toString().padLeft(2, '0')}.${startedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dateLabel, style: AppText.body(size: 12.5, weight: FontWeight.w600)),
            Text('$distanceKm km · $minutes mnt', style: AppText.body(size: 11, color: AppColors.mut)),
          ]),
        ),
        Text('+$points', style: AppText.num(size: 13, color: AppColors.accent)),
      ]),
    );
  }
}

class _PointBreakdownRow extends StatelessWidget {
  final PointBreakdownEntry entry;
  final bool isLast;
  const _PointBreakdownRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.ruleName, style: AppText.body(size: 13, weight: FontWeight.w600)),
            Text('${entry.timesAwarded} kali', style: AppText.body(size: 11, color: AppColors.mut)),
          ]),
        ),
        Text('+${entry.totalPoints}', style: AppText.num(size: 14, color: AppColors.violet)),
      ]),
    );
  }
}
