import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../models/leaderboard_my_position.dart';
import '../services/health_connect_service.dart';
import '../state/activity_state.dart';
import '../state/app_state.dart';
import '../state/employee_state.dart';
import '../state/history_state.dart';
import '../state/leaderboard_state.dart';
import '../state/employee_detail_state.dart';
import '../state/monitoring_state.dart';
import '../state/points_state.dart';
import '../state/walk_session_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/common.dart';
import '../widgets/health_connect_rationale_dialog.dart';
import '../widgets/step_ring.dart';

/// Builds the "Posisimu di Divisi X minggu ini — naik/turun N peringkat"
/// blurb. rank_change is null whenever there's no prior-week ranking to
/// compare against (e.g. the app's very first week) — shown neutrally,
/// without an invented naik/turun claim.
TextSpan _leaderboardBlurb(LeaderboardMyPosition? position) {
  const neutralStyle = TextStyle();
  const changeStyle = TextStyle(color: AppColors.accent);

  if (position == null) {
    return const TextSpan(
      text: 'Memuat posisi peringkatmu...',
      style: neutralStyle,
    );
  }

  final intro = 'Posisimu di Divisi ${position.sub} minggu ini';
  final change = position.rankChange;
  if (change == null) {
    return TextSpan(text: '$intro.', style: neutralStyle);
  }
  if (change == 0) {
    return TextSpan(
      text: '$intro — bertahan di peringkat yang sama dari minggu lalu.',
      style: neutralStyle,
    );
  }

  final verb = change > 0 ? 'naik' : 'turun';
  return TextSpan(
    style: neutralStyle,
    children: [
      TextSpan(text: '$intro — '),
      TextSpan(text: '$verb ${change.abs()} peringkat', style: changeStyle),
      const TextSpan(text: ' dari minggu lalu.'),
    ],
  );
}

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  @override
  void initState() {
    super.initState();
    // Always fetch fresh on entering Beranda — today's step count can
    // change between visits (a real Health Connect sync, or the manual
    // "Sync Sekarang" button below).
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final activityState = context.read<ActivityState>();
    final pointsState = context.read<PointsState>();
    final leaderboardState = context.read<LeaderboardState>();

    activityState.beginLoading();

    // Auto-sync on open, but only if Health Connect permission was already
    // granted in an earlier session — silently popping the OS permission
    // dialog the instant Beranda opens (before the user has even seen the
    // app) would be poor form. A first-time sync only happens via the
    // explicit "Sinkron Sekarang" tap, which shows a rationale dialog
    // first. Sequenced (not Future.wait) so a sync's newly-awarded points
    // are already in place before points/leaderboard are fetched.
    //
    // No `mounted` guard here even though this awaits real async work:
    // activityState/pointsState/leaderboardState were captured above (not
    // read fresh from context), and syncNow()/fetchToday() always resolve
    // isLoading back to false themselves — bailing out here on an
    // unmounted widget would leave isLoading stuck true forever with
    // nothing left to unstick it.
    final hasHealthPermission = await HealthConnectService.instance
        .hasPermission();
    if (hasHealthPermission) {
      await activityState.syncNow();
    } else {
      await activityState.fetchToday();
    }
    if (!mounted) return;

    await Future.wait([
      pointsState.fetchSummary(),
      leaderboardState.fetchMyPosition(),
    ]);
    if (!mounted) return;
    if (activityState.sessionExpired ||
        pointsState.sessionExpired ||
        leaderboardState.myPositionSessionExpired) {
      // Token is no longer valid server-side — bounce to Login instead of
      // showing a raw error on the ring.
      context.read<EmployeeState>().clear();
      activityState.clear();
      pointsState.clear();
      leaderboardState.clear();
      context.read<HistoryState>().clear();
      context.read<WalkSessionState>().clear();
      context.read<MonitoringState>().clear();
      context.read<EmployeeDetailState>().clear();
      context.read<AppState>().logout();
    }
  }

  /// "Sinkron Sekarang" — reads real Health Connect step data (not a random
  /// number) and syncs it. Shows a rationale dialog before the system
  /// permission prompt the first time, per the onboarding copy style used
  /// elsewhere in the app.
  Future<void> _handleSyncTap() async {
    if (!await HealthConnectService.instance.hasPermission()) {
      if (!mounted) return;
      final proceed = await showHealthConnectRationale(context);
      if (proceed != true) return;
      if (!mounted) return;
      final granted = await HealthConnectService.instance.requestPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin Health Connect ditolak. Kamu bisa mencoba menyambungkan lagi kapan saja dari sini.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;

    await context.read<ActivityState>().syncNow();
    if (!mounted) return;
    await Future.wait([
      context.read<PointsState>().fetchSummary(),
      context.read<LeaderboardState>().fetchMyPosition(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final employee = context.watch<EmployeeState>().employee;
    final activity = context.watch<ActivityState>();
    final points = context.watch<PointsState>();
    final myPosition = context.watch<LeaderboardState>().myPosition;
    final remaining = (activity.targetSteps - activity.steps).clamp(
      0,
      activity.targetSteps,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.greeting},',
                      style: AppText.body(size: 13, color: AppColors.mut),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee?.fullName ?? '—',
                      style: AppText.heading(size: 24, height: 1.1),
                    ),
                    const SizedBox(height: 6),
                    PillTag(
                      text: employee?.divisionName ?? '—',
                      color: AppColors.accent,
                      background: AppColors.accentTint,
                      icon: Icons.work_outline,
                    ),
                  ],
                ),
              ),
              // Manual "Sinkron Sekarang" — pulls real step data from Health
              // Connect (see ActivityState.syncNow / HealthConnectService).
              GestureDetector(
                onTap: activity.isSyncing ? null : _handleSyncTap,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.line),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: activity.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : const Icon(
                            Icons.sync,
                            size: 18,
                            color: AppColors.accent,
                          ),
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.line),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 18,
                        color: AppColors.text,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 9,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.amber,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.bg, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Column(
              children: [
                if (activity.isLoading && activity.steps == 0)
                  const SizedBox(
                    width: 224,
                    height: 224,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                else
                  StepRing(
                    progress: activity.progress,
                    steps: activity.steps,
                    goal: activity.targetSteps,
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 260,
                  child: Text.rich(
                    remaining <= 0
                        ? const TextSpan(
                            text: 'Target harian tercapai — kerja bagus!',
                          )
                        : TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Ayo lanjutkan langkahmu — ',
                              ),
                              TextSpan(
                                text: '$remaining langkah',
                                style: const TextStyle(color: AppColors.accent),
                              ),
                              const TextSpan(
                                text: ' lagi menuju target hari ini!',
                              ),
                            ],
                          ),
                    style: AppText.body(size: 12.5, color: AppColors.mut),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in MockData.weekStrip)
                  Column(
                    children: [
                      Text(
                        d.label,
                        style: AppText.body(size: 10, color: AppColors.mut),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: d.done
                              ? AppColors.accentTint
                              : Colors.transparent,
                          border: Border.all(
                            color: d.done
                                ? AppColors.accent
                                : const Color(0xFF2B2B2B),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          d.done ? Icons.check : Icons.remove,
                          size: 14,
                          color: d.done ? AppColors.accent : AppColors.dim,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.route,
                  iconColor: AppColors.accent,
                  value: '4,7',
                  valueColor: AppColors.accent,
                  label: 'km hari ini',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.local_fire_department,
                  iconColor: AppColors.amber,
                  value: '248',
                  valueColor: AppColors.amberSoft,
                  label: 'kkal (est.)',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.auto_awesome,
                  iconColor: AppColors.violet,
                  value: '+${points.pointsToday}',
                  valueColor: AppColors.violet,
                  label: 'poin hari ini',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => state.go(AppScreen.jalan),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_walk,
                      color: Color(0xFF06231A),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mulai Jalan Kaki',
                          style: AppText.heading(
                            size: 18,
                            color: const Color(0xFF06231A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Rekam rutemu & kumpulkan poin',
                          style: AppText.body(
                            size: 12,
                            color: const Color(
                              0xFF06231A,
                            ).withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF06231A)),
                ],
              ),
            ),
          ),
          if (points.currentStreakDays > 0)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.amberTint,
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.28),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      size: 22,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${points.currentStreakDays} hari beruntun!',
                          style: AppText.heading(
                            size: 16,
                            color: AppColors.amberSoft,
                          ),
                        ),
                        Text(
                          'Kamu mencapai target ${points.currentStreakDays} hari berturut-turut. Pertahankan ya.',
                          style: AppText.body(size: 12, color: AppColors.mut),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: () => state.go(AppScreen.papan),
            child: Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'PAPAN PERINGKAT · MINGGUAN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 10,
                            color: AppColors.accent,
                          ).copyWith(letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lihat semua',
                            style: AppText.body(
                              size: 12,
                              color: AppColors.accent,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        myPosition != null ? '#${myPosition.rank}' : '#—',
                        style: AppText.num(size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          _leaderboardBlurb(myPosition),
                          style: AppText.body(size: 12.5, color: AppColors.mut),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
