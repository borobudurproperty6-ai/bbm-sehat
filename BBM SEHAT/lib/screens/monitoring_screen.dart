import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monitoring.dart';
import '../state/activity_state.dart';
import '../state/app_state.dart';
import '../state/employee_detail_state.dart';
import '../state/employee_state.dart';
import '../state/history_state.dart';
import '../state/leaderboard_state.dart';
import '../state/monitoring_state.dart';
import '../services/walk_reminder_service.dart';
import '../state/points_state.dart';
import '../state/walk_session_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/common.dart';

/// Company-wide monitoring dashboard — only reachable via the bottom nav's
/// Monitoring tab, which BbmBottomNavBar only shows for a qualifying role
/// (see Employee.canAccessMonitoring). The backend enforces the same gate
/// independently (MONITORING_API.md), so [MonitoringState.forbidden] below
/// is a defensive fallback, not the primary access control.
class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // The employee list lives inside the same single scroll view as the rest
  // of the dashboard (overview cards, division ranking) rather than its own
  // nested ListView — a scrollable-inside-scrollable fights over vertical
  // drag gestures. Triggering 300px before the true bottom hides the
  // network round-trip behind normal scroll momentum.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      context.read<MonitoringState>().loadMoreEmployees();
    }
  }

  Future<void> _load() async {
    final monitoring = context.read<MonitoringState>();
    await monitoring.fetchAll();
    if (!mounted) return;
    if (monitoring.sessionExpired) {
      context.read<EmployeeState>().clear();
      context.read<ActivityState>().clear();
      context.read<PointsState>().clear();
      context.read<LeaderboardState>().clear();
      context.read<HistoryState>().clear();
      context.read<WalkSessionState>().clear();
      context.read<EmployeeDetailState>().clear();
      monitoring.clear();
      context.read<AppState>().logout();
    }
  }

  Future<void> _changeInactiveDays(int days) async {
    await context.read<MonitoringState>().fetchTidakAktif(days: days);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      context.read<MonitoringState>().fetchEmployees(search: value.trim());
    });
  }

  void _onSortChanged(EmployeeSortBy sortBy) {
    context.read<MonitoringState>().fetchEmployees(sortBy: sortBy);
  }

  void _openEmployee(int employeeId) {
    context.read<EmployeeDetailState>().clear();
    context.read<AppState>().openEmployeeDetail(employeeId);
  }

  @override
  Widget build(BuildContext context) {
    final monitoring = context.watch<MonitoringState>();

    if (monitoring.forbidden) {
      return _ForbiddenNotice(onRetry: _load);
    }

    // A single CustomScrollView, not a SingleChildScrollView wrapping plain
    // Columns — the fixed-content sections (overview/division/inactive/
    // search+sort header) live in one SliverList, and the employee list
    // (the one part that can genuinely grow to 48+ items and drives
    // infinite scroll) is its own lazily-built SliverList.builder. Both
    // slivers share _scrollController, so _onScroll's maxScrollExtent
    // check still refers to the same single scroll position as before.
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 10),
              Text('Monitoring', style: AppText.heading(size: 25)),
              const SizedBox(height: 3),
              Text('Ringkasan aktivitas seluruh perusahaan',
                  style: AppText.body(size: 12.5, color: AppColors.mut)),
              const SizedBox(height: 18),
              const _WalkReminderButton(),
              const SizedBox(height: 18),
              _OverviewSection(
                  monitoring: monitoring, onRetry: () => context.read<MonitoringState>().fetchOverview()),
              const SectionLabel('Ranking Antar Divisi'),
              _DivisionSection(
                  monitoring: monitoring, onRetry: () => context.read<MonitoringState>().fetchPerDivisi()),
              const SectionLabel('Perlu Perhatian'),
              _InactiveSection(monitoring: monitoring, onDaysChanged: _changeInactiveDays),
              const SectionLabel('Progres Karyawan'),
              _EmployeeProgressHeader(
                monitoring: monitoring,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onSortChanged: _onSortChanged,
              ),
              const SizedBox(height: 14),
            ]),
          ),
        ),
        ..._employeeListSlivers(monitoring, _openEmployee),
      ],
    );
  }

  List<Widget> _employeeListSlivers(MonitoringState monitoring, ValueChanged<int> onTapEmployee) {
    const horizontalPadding = EdgeInsets.symmetric(horizontal: 18);
    // One trailing spacer sliver appended to every branch below, so the
    // bottom nav bar never covers the last row regardless of whether the
    // list ended up loading/erroring/empty/populated.
    const bottomSpacer = SliverPadding(padding: EdgeInsets.only(bottom: 90));

    if (monitoring.isLoadingEmployees && monitoring.employeeList.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 24),
          sliver: SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ),
        ),
        bottomSpacer,
      ];
    }

    if (monitoring.employeeList.isEmpty && monitoring.employeesError != null) {
      return [
        SliverPadding(
          padding: horizontalPadding,
          sliver: SliverToBoxAdapter(
            child: _ErrorRow(
              message: monitoring.employeesError!,
              onRetry: () => _onSortChanged(monitoring.employeeSortBy),
            ),
          ),
        ),
        bottomSpacer,
      ];
    }

    if (monitoring.employeeList.isEmpty) {
      return [
        SliverPadding(
          padding: horizontalPadding,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                monitoring.employeeSearch.isEmpty
                    ? 'Belum ada data karyawan.'
                    : 'Tidak ada karyawan dengan nama "${monitoring.employeeSearch}".',
                style: AppText.body(size: 12.5, color: AppColors.mut),
              ),
            ),
          ),
        ),
        bottomSpacer,
      ];
    }

    return [
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final e = monitoring.employeeList[index];
              return _EmployeeCard(entry: e, onTap: () => onTapEmployee(e.id));
            },
            childCount: monitoring.employeeList.length,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: monitoring.isLoadingMoreEmployees
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
              )
            : const SizedBox.shrink(),
      ),
      bottomSpacer,
    ];
  }
}

class _ForbiddenNotice extends StatelessWidget {
  final VoidCallback onRetry;
  const _ForbiddenNotice({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 32, color: AppColors.mut),
          const SizedBox(height: 12),
          Text('Anda tidak memiliki akses ke halaman ini.',
              textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppColors.mut)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text('Coba lagi', style: AppText.body(size: 13, color: AppColors.accent)),
          ),
        ]),
      ),
    );
  }
}

/// Manual demo trigger — sends "Ayo Jalan Kaki!" push notifications to
/// every active employee who hasn't reached their step target yet today
/// and has a device registered (POST /api/admin/send-walk-reminder). Not
/// backed by MonitoringState since it's a one-shot action with its own
/// local loading state, not data the rest of the screen depends on.
class _WalkReminderButton extends StatefulWidget {
  const _WalkReminderButton();

  @override
  State<_WalkReminderButton> createState() => _WalkReminderButtonState();
}

class _WalkReminderButtonState extends State<_WalkReminderButton> {
  bool _isSending = false;

  Future<void> _send() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    final result = await WalkReminderService.instance.send();
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.unauthorized) {
      context.read<AppState>().logout();
      return;
    }

    final String message;
    if (result.success) {
      final sent = result.sentCount ?? 0;
      final failed = result.failedCount ?? 0;
      message = failed > 0
          ? 'Reminder terkirim ke $sent karyawan, $failed gagal terkirim.'
          : 'Reminder terkirim ke $sent karyawan.';
    } else if (result.forbidden) {
      message = 'Anda tidak memiliki akses untuk mengirim reminder ini.';
    } else {
      message = result.errorMessage ?? 'Gagal mengirim reminder.';
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const onAccent = Color(0xFF06231A);

    return GestureDetector(
      onTap: _isSending ? null : _send,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isSending ? AppColors.accent.withValues(alpha: 0.6) : AppColors.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: onAccent),
                    )
                  : const Icon(Icons.notifications_active_outlined, color: onAccent),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kirim Reminder Jalan Kaki', style: AppText.heading(size: 15, color: onAccent)),
              Text('Ingatkan karyawan yang belum capai target hari ini',
                  style: AppText.body(size: 11.5, color: onAccent.withValues(alpha: 0.75))),
            ]),
          ),
          if (!_isSending) const Icon(Icons.chevron_right, color: onAccent),
        ]),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final MonitoringState monitoring;
  final VoidCallback onRetry;
  const _OverviewSection({required this.monitoring, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (monitoring.isLoadingOverview && monitoring.overview == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (monitoring.overview == null && monitoring.overviewError != null) {
      return _ErrorRow(message: monitoring.overviewError!, onRetry: onRetry);
    }

    final overview = monitoring.overview;
    if (overview == null) return const SizedBox.shrink();

    final participation = overview.participationRateThisWeek.toStringAsFixed(1).replaceAll('.', ',');
    final km = overview.totalKmThisWeek.toStringAsFixed(1).replaceAll('.', ',');

    return Column(children: [
      Row(children: [
        Expanded(
          child: StatTile(
            icon: Icons.groups_outlined,
            iconColor: AppColors.sky,
            value: '${overview.totalEmployeesActive}',
            valueColor: AppColors.text,
            label: 'Karyawan aktif',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            icon: Icons.trending_up,
            iconColor: AppColors.accent,
            value: '$participation%',
            valueColor: AppColors.accent,
            label: 'Partisipasi minggu ini',
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: StatTile(
            icon: Icons.route_outlined,
            iconColor: AppColors.violet,
            value: '$km km',
            valueColor: AppColors.violet,
            label: 'Total jarak perusahaan',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            icon: Icons.directions_walk,
            iconColor: AppColors.amberSoft,
            value: '${overview.totalStepsThisWeek}',
            valueColor: AppColors.amberSoft,
            label: 'Total langkah',
          ),
        ),
      ]),
    ]);
  }
}

class _DivisionSection extends StatelessWidget {
  final MonitoringState monitoring;
  final VoidCallback onRetry;
  const _DivisionSection({required this.monitoring, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (monitoring.isLoadingDivisions && monitoring.divisions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (monitoring.divisions.isEmpty && monitoring.divisionsError != null) {
      return _ErrorRow(message: monitoring.divisionsError!, onRetry: onRetry);
    }

    if (monitoring.divisions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Belum ada data divisi.', style: AppText.body(size: 12.5, color: AppColors.mut)),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        for (var i = 0; i < monitoring.divisions.length; i++)
          _DivisionRow(entry: monitoring.divisions[i], isLast: i == monitoring.divisions.length - 1),
      ]),
    );
  }
}

class _DivisionRow extends StatelessWidget {
  final DivisionMonitoringEntry entry;
  final bool isLast;
  const _DivisionRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(children: [
        SizedBox(
          width: 22,
          child: Text('${entry.rank}',
              textAlign: TextAlign.center,
              style: AppText.num(size: 14, weight: FontWeight.w400, color: AppColors.mut)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.divisionName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 13.5, weight: FontWeight.w600)),
            Text('${entry.employeeCount} karyawan · ${entry.avgSteps} langkah rata-rata',
                style: AppText.body(size: 11, color: AppColors.mut)),
          ]),
        ),
        Text('${entry.avgPoints.toStringAsFixed(1).replaceAll('.', ',')} poin',
            style: AppText.num(size: 13, weight: FontWeight.w400, color: AppColors.accent)),
      ]),
    );
  }
}

class _InactiveSection extends StatelessWidget {
  final MonitoringState monitoring;
  final ValueChanged<int> onDaysChanged;
  const _InactiveSection({required this.monitoring, required this.onDaysChanged});

  @override
  Widget build(BuildContext context) {
    const dayOptions = [7, 14, 30];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SegmentedTabs(
        labels: dayOptions.map((d) => '$d hari').toList(),
        selectedIndex: dayOptions.indexOf(monitoring.inactiveDays).clamp(0, dayOptions.length - 1),
        onChanged: (i) => onDaysChanged(dayOptions[i]),
      ),
      const SizedBox(height: 14),
      if (monitoring.isLoadingInactive && monitoring.inactiveEmployees.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        )
      else if (monitoring.inactiveEmployees.isEmpty && monitoring.inactiveError != null)
        _ErrorRow(message: monitoring.inactiveError!, onRetry: () => onDaysChanged(monitoring.inactiveDays))
      else if (monitoring.inactiveEmployees.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_outline, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Semua karyawan aktif dalam ${monitoring.inactiveDays} hari terakhir.',
                style: AppText.body(size: 12.5, color: AppColors.mut),
              ),
            ),
          ]),
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
            for (var i = 0; i < monitoring.inactiveEmployees.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: i < monitoring.inactiveEmployees.length - 1
                      ? const Border(bottom: BorderSide(color: AppColors.line))
                      : null,
                ),
                child: Row(children: [
                  Avatar(
                    initials: _initialsOf(monitoring.inactiveEmployees[i].fullName),
                    imageUrl: monitoring.inactiveEmployees[i].photoUrl,
                    size: 34,
                    fontSize: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(monitoring.inactiveEmployees[i].fullName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 13.5, weight: FontWeight.w600)),
                      Text(monitoring.inactiveEmployees[i].divisionName,
                          style: AppText.body(size: 11, color: AppColors.mut)),
                    ]),
                  ),
                  Text(
                    monitoring.inactiveEmployees[i].lastActivityDate ?? 'Belum pernah',
                    style: AppText.body(size: 11, color: AppColors.amberSoft),
                  ),
                ]),
              ),
          ]),
        ),
    ]);
  }

  static String _initialsOf(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

/// Search field + sort chips only — the employee cards themselves live in
/// their own SliverList.builder (see _employeeListSlivers) so this widget
/// no longer owns any part of the list.
class _EmployeeProgressHeader extends StatelessWidget {
  final MonitoringState monitoring;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<EmployeeSortBy> onSortChanged;

  const _EmployeeProgressHeader({
    required this.monitoring,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        style: AppText.body(size: 13.5),
        decoration: InputDecoration(
          hintText: 'Cari nama karyawan...',
          hintStyle: AppText.body(size: 13.5, color: AppColors.mut),
          prefixIcon: const Icon(Icons.search, size: 19, color: AppColors.mut),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 32,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final option in EmployeeSortBy.values) ...[
            _SortChip(
              label: option.label,
              selected: monitoring.employeeSortBy == option,
              onTap: () => onSortChanged(option),
            ),
            const SizedBox(width: 8),
          ],
        ]),
      ),
    ]);
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentTint : AppColors.card,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.body(size: 12, color: selected ? AppColors.accent : AppColors.mut),
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmployeeListItem entry;
  final VoidCallback onTap;
  const _EmployeeCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Avatar(initials: _initialsOf(entry.fullName), imageUrl: entry.photoUrl, size: 40, fontSize: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(entry.fullName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 13.5, weight: FontWeight.w600)),
                ),
                Container(
                  width: 7, height: 7,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.isActiveRecently ? AppColors.accent : AppColors.dim,
                  ),
                ),
              ]),
              Text(entry.divisionName, style: AppText.body(size: 11, color: AppColors.mut)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.directions_walk, size: 12, color: AppColors.mut),
                const SizedBox(width: 3),
                Text('${entry.stepsThisWeek}', style: AppText.body(size: 11, color: AppColors.mut)),
                const SizedBox(width: 12),
                const Icon(Icons.local_fire_department, size: 12, color: AppColors.amberSoft),
                const SizedBox(width: 3),
                Text('${entry.currentStreakDays} hari', style: AppText.body(size: 11, color: AppColors.mut)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${entry.totalPoints}', style: AppText.num(size: 17, color: AppColors.violet)),
            Text('poin', style: AppText.body(size: 10, color: AppColors.mut)),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.dim),
        ]),
      ),
    );
  }

  static String _initialsOf(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRow({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: [
        Text(message, textAlign: TextAlign.center, style: AppText.body(size: 12.5, color: AppColors.mut)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          child: Text('Coba lagi', style: AppText.body(size: 13, color: AppColors.accent)),
        ),
      ]),
    );
  }
}
