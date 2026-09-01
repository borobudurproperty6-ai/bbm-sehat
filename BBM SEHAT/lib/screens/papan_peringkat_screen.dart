import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/leaderboard_service.dart';
import '../state/app_state.dart';
import '../state/employee_state.dart';
import '../state/leaderboard_state.dart';
import '../state/employee_detail_state.dart';
import '../state/monitoring_state.dart';
import '../state/points_state.dart';
import '../state/walk_session_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/common.dart';

LeaderboardScope _scopeFor(PapanTab tab) => switch (tab) {
  PapanTab.divisi => LeaderboardScope.ownDivision,
  PapanTab.semua => LeaderboardScope.allEmployees,
  PapanTab.perusahaan => LeaderboardScope.byDivision,
};

class PapanPeringkatScreen extends StatefulWidget {
  const PapanPeringkatScreen({super.key});

  @override
  State<PapanPeringkatScreen> createState() => _PapanPeringkatScreenState();
}

class _PapanPeringkatScreenState extends State<PapanPeringkatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _load(context.read<AppState>().papanTab),
    );
  }

  Future<void> _load(PapanTab tab) async {
    final leaderboardState = context.read<LeaderboardState>();
    await leaderboardState.fetchEntries(scope: _scopeFor(tab));
    if (!mounted) return;
    if (leaderboardState.entriesSessionExpired) {
      context.read<EmployeeState>().clear();
      context.read<PointsState>().clear();
      leaderboardState.clear();
      context.read<WalkSessionState>().clear();
      context.read<MonitoringState>().clear();
      context.read<EmployeeDetailState>().clear();
      context.read<AppState>().logout();
    }
  }

  void _onTabChanged(PapanTab tab) {
    context.read<AppState>().setPapanTab(tab);
    _load(tab);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final leaderboard = context.watch<LeaderboardState>();

    final podium = leaderboard.entries.where((e) => e.rank <= 3).toList();
    final board = leaderboard.entries.where((e) => e.rank > 3).toList();
    // Present as [2nd, 1st, 3rd] visually — some scopes (a division with
    // only 1-2 people) won't have all three ranks, so only render whichever
    // actually exist.
    LeaderboardEntry? byRank(int r) =>
        podium.where((p) => p.rank == r).firstOrNull;
    final ordered = [
      byRank(2),
      byRank(1),
      byRank(3),
    ].whereType<LeaderboardEntry>().toList();
    final me = leaderboard.entries.where((e) => e.isMe).firstOrNull;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text('Papan Peringkat', style: AppText.heading(size: 25)),
              const SizedBox(height: 14),
              SegmentedTabs(
                labels: const ['Divisi', 'Semua Divisi', 'Perusahaan'],
                selectedIndex: PapanTab.values.indexOf(state.papanTab),
                onChanged: (i) => _onTabChanged(PapanTab.values[i]),
              ),
              const SizedBox(height: 18),
              if (leaderboard.isLoadingEntries && leaderboard.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 44),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (leaderboard.entries.isEmpty &&
                  leaderboard.entriesError != null)
                Padding(
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
                        leaderboard.entriesError!,
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 12.5, color: AppColors.mut),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => _load(state.papanTab),
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
              else ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final p in ordered)
                        Expanded(child: _PodiumSpot(entry: p)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < board.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: board[i].isMe
                                ? AppColors.accentTint
                                : Colors.transparent,
                            border: i < board.length - 1
                                ? const Border(
                                    bottom: BorderSide(color: AppColors.line),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                child: Text(
                                  '${board[i].rank}',
                                  textAlign: TextAlign.center,
                                  style: AppText.num(
                                    size: 14,
                                    weight: FontWeight.w400,
                                    color: AppColors.mut,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Avatar(
                                initials: board[i].initials,
                                imageUrl: board[i].photoUrl,
                                size: 36,
                                fontSize: 13,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      board[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.body(
                                        size: 13.5,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      board[i].sub,
                                      style: AppText.body(
                                        size: 11,
                                        color: AppColors.mut,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                board[i].points,
                                style: AppText.num(
                                  size: 13,
                                  weight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (me != null)
          Positioned(
            left: 18,
            right: 18,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${me.rank}',
                      textAlign: TextAlign.center,
                      style: AppText.num(
                        size: 14,
                        color: const Color(0xFF06231A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Avatar(
                    initials: me.initials,
                    imageUrl: me.photoUrl,
                    size: 36,
                    fontSize: 13,
                    borderColor: Colors.black.withValues(alpha: 0.16),
                    textColor: const Color(0xFF06231A),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${me.name} (Kamu)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: const Color(0xFF06231A),
                          ),
                        ),
                        Text(
                          me.sub,
                          style: AppText.body(
                            size: 11,
                            color: const Color(
                              0xFF06231A,
                            ).withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    me.points,
                    style: AppText.num(
                      size: 13,
                      weight: FontWeight.w700,
                      color: const Color(0xFF06231A),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final LeaderboardEntry entry;
  const _PodiumSpot({required this.entry});

  @override
  Widget build(BuildContext context) {
    final Color ring = switch (entry.rank) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      _ => AppColors.bronze,
    };
    final double avatarSize = entry.rank == 1 ? 62 : 54;
    final double initSize = entry.rank == 1 ? 22 : 19;

    return Column(
      children: [
        SizedBox(
          height: 74,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Avatar(
                initials: entry.initials,
                imageUrl: entry.photoUrl,
                size: avatarSize,
                fontSize: initSize,
                borderColor: ring,
              ),
              Positioned(
                top: avatarSize - 8,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ring,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  child: Text(
                    '${entry.rank}',
                    style: AppText.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: const Color(0xFF0D0D0D),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          entry.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(size: 12, weight: FontWeight.w600),
        ),
        Text(entry.sub, style: AppText.body(size: 10, color: AppColors.mut)),
        const SizedBox(height: 2),
        Text(
          entry.points,
          style: AppText.body(size: 12.5, color: AppColors.accent),
        ),
      ],
    );
  }
}
