import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/activity_history.dart';
import '../models/walk_session.dart';
import '../services/activity_service.dart';
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
import '../utils/polyline_codec.dart';
import '../widgets/common.dart';
import '../widgets/route_map.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _load(context.read<AppState>().histRange),
    );
  }

  Future<void> _load(HistRange range) async {
    final historyState = context.read<HistoryState>();
    final walkSessionState = context.read<WalkSessionState>();
    await Future.wait([
      historyState.fetch(
        range == HistRange.minggu
            ? HistoryPeriod.weekly
            : HistoryPeriod.monthly,
      ),
      walkSessionState.fetchHistory(),
    ]);
    if (!mounted) return;
    if (historyState.sessionExpired || walkSessionState.historySessionExpired) {
      context.read<EmployeeState>().clear();
      context.read<ActivityState>().clear();
      context.read<PointsState>().clear();
      context.read<LeaderboardState>().clear();
      historyState.clear();
      walkSessionState.clear();
      context.read<MonitoringState>().clear();
      context.read<EmployeeDetailState>().clear();
      context.read<AppState>().logout();
    }
  }

  void _onToggle(HistRange range) {
    context.read<AppState>().setHistRange(range);
    _load(range);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isWeek = state.histRange == HistRange.minggu;
    final historyState = context.watch<HistoryState>();
    final history = historyState.history;
    final entries = history?.entries ?? const <ActivityHistoryEntry>[];
    final maxSteps = entries.isEmpty
        ? 0
        : entries.map((e) => e.steps).reduce((a, b) => a > b ? a : b);
    final walkSessionState = context.watch<WalkSessionState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text('Riwayat Aktivitas', style: AppText.heading(size: 25)),
          const SizedBox(height: 14),
          Center(
            child: SegmentedTabs(
              labels: const ['Mingguan', 'Bulanan'],
              selectedIndex: isWeek ? 0 : 1,
              onChanged: (i) =>
                  _onToggle(i == 0 ? HistRange.minggu : HistRange.bulan),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: historyState.isLoading && history == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 44),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                : history == null && historyState.error != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 28,
                          color: AppColors.mut,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          historyState.error!,
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 12.5, color: AppColors.mut),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => _load(state.histRange),
                          child: Text(
                            'Coba lagi',
                            style: AppText.body(
                              size: 13,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rata-rata ${isWeek ? 'harian' : 'mingguan'}',
                                  style: AppText.body(
                                    size: 11,
                                    color: AppColors.mut,
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _fmt(history?.averageDailySteps ?? 0),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.num(size: 26),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'langkah',
                                      style: AppText.body(
                                        size: 12,
                                        color: AppColors.mut,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PillTag(
                            text: 'Target ${_fmt(history?.targetSteps ?? 0)}',
                            color: AppColors.accent,
                            background: AppColors.accentTint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 150,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final e in entries)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(
                                          begin: 0,
                                          end: maxSteps > 0
                                              ? e.steps / maxSteps
                                              : 0.0,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        builder: (context, v, _) => Container(
                                          height: 120 * v,
                                          decoration: BoxDecoration(
                                            color: e.targetMet == true
                                                ? AppColors.amber
                                                : AppColors.accent,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(6),
                                                  topRight: Radius.circular(6),
                                                  bottomLeft: Radius.circular(
                                                    3,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    3,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        e.label,
                                        style: AppText.body(
                                          size: 10,
                                          color: AppColors.mut,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SectionLabel('Sesi Jalan Kaki'),
          if (walkSessionState.isLoadingHistory &&
              walkSessionState.history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (walkSessionState.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Belum ada sesi jalan kaki tersimpan — mulai dari tombol "Mulai Jalan Kaki" di Beranda.',
                style: AppText.body(size: 12.5, color: AppColors.mut),
              ),
            )
          else
            for (final s in walkSessionState.history)
              _WalkSessionCard(session: s),
          const SectionLabel(
            'Langkah Pasif (Health Connect)',
            padding: EdgeInsets.fromLTRB(2, 8, 2, 8),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada data langkah untuk periode ini.',
                style: AppText.body(size: 12.5, color: AppColors.mut),
              ),
            )
          else
            for (final e in entries)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 2,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: e.date != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat(
                                    'MMM',
                                    'id_ID',
                                  ).format(DateTime.parse(e.date!)).toUpperCase(),
                                  style: AppText.body(
                                    size: 9,
                                    color: AppColors.mut,
                                  ),
                                ),
                                Text(
                                  '${DateTime.parse(e.date!).day}',
                                  style: AppText.num(size: 15),
                                ),
                              ],
                            )
                          : Text(
                              e.label,
                              textAlign: TextAlign.center,
                              style: AppText.body(size: 10, color: AppColors.mut),
                            ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_fmt(e.steps)} langkah',
                            style: AppText.body(size: 14),
                          ),
                          if (e.targetMet != null)
                            Text(
                              e.targetMet!
                                  ? 'Target tercapai'
                                  : 'Belum capai target',
                              style: AppText.body(
                                size: 11.5,
                                color: e.targetMet!
                                    ? AppColors.accent
                                    : AppColors.mut,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

Widget _chip(String text, Color bg, Color fg, {bool bold = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
  child: Text(
    text,
    style: AppText.body(
      size: 11,
      weight: bold ? FontWeight.w600 : FontWeight.w400,
      color: fg,
    ),
  ),
);

/// One real, saved walk session — decodes route_polyline into the
/// lightweight RouteMap thumbnail's coordinate space rather than embedding
/// an interactive Google Map per list item.
class _WalkSessionCard extends StatelessWidget {
  final WalkSession session;
  const _WalkSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'd MMM · HH.mm',
      'id_ID',
    ).format(session.startedAt);
    final distanceKm = ((session.distanceMeters ?? 0) / 1000)
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    final minutes = ((session.durationSeconds ?? 0) / 60).round();
    final points = session.pointsAwarded ?? 0;

    final decoded =
        session.routePolyline == null || session.routePolyline!.isEmpty
        ? const <RoutePoint>[]
        : decodePolyline(session.routePolyline!);
    final waypoints = normalizeRoutePoints(
      decoded.map((p) => (lat: p.lat, lng: p.lng)).toList(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RouteMap(
                    variant: RouteVariant.mini,
                    customWaypoints: waypoints,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: _chip(
                    dateLabel,
                    Colors.black.withValues(alpha: 0.55),
                    const Color(0xFFE5EBE8),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: _chip(
                    '+$points',
                    AppColors.route,
                    const Color(0xFF06231A),
                    bold: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleFor(session.startedAt),
                  style: AppText.heading(size: 13.5),
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      distanceKm,
                      style: AppText.num(size: 25, color: AppColors.accent),
                    ),
                    Text(
                      ' km',
                      style: AppText.body(size: 12, color: AppColors.mut),
                    ),
                    const SizedBox(width: 20),
                    Text('$minutes', style: AppText.num(size: 25)),
                    Text(
                      ' mnt',
                      style: AppText.body(size: 12, color: AppColors.mut),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _titleFor(DateTime startedAt) {
    final h = startedAt.hour;
    if (h < 11) return 'Jalan Pagi';
    if (h < 15) return 'Jalan Siang';
    if (h < 18) return 'Jalan Sore';
    return 'Jalan Malam';
  }
}
