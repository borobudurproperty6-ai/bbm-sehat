import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/health_connect_service.dart';
import '../services/profile_photo_service.dart';
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

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  bool _healthConnected = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    // Always fetch fresh on entering this screen — cheap, and guarantees a
    // different account after logout/login never shows stale cached data.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final employeeState = context.read<EmployeeState>();
    // Kicked off alongside the others but awaited separately — Future.wait
    // needs one uniform type, and this one returns bool, not void.
    final healthConnectedFuture = HealthConnectService.instance.hasPermission();
    await Future.wait([
      employeeState.fetchMe(),
      context.read<PointsState>().fetchSummary(),
    ]);
    final healthConnected = await healthConnectedFuture;
    if (!mounted) return;
    setState(() => _healthConnected = healthConnected);
    if (employeeState.sessionExpired) {
      // Token is no longer valid server-side (expired/revoked) — bounce to
      // Login instead of showing a raw error.
      context.read<ActivityState>().clear();
      context.read<PointsState>().clear();
      context.read<LeaderboardState>().clear();
      context.read<HistoryState>().clear();
      context.read<WalkSessionState>().clear();
      context.read<MonitoringState>().clear();
      context.read<EmployeeDetailState>().clear();
      context.read<AppState>().logout();
    }
  }

  Future<void> _connectHealthConnect() async {
    final proceed = await showHealthConnectRationale(context);
    if (proceed != true) return;
    if (!mounted) return;

    final granted = await HealthConnectService.instance.requestPermission();
    if (!mounted) return;
    if (!granted) {
      // _healthConnected was already false — nothing to roll back — but
      // silently doing nothing here reads as a broken tap, not a denial.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Izin Health Connect ditolak. Kamu bisa mencoba menyambungkan lagi kapan saja dari sini.',
          ),
        ),
      );
      return;
    }
    setState(() => _healthConnected = true);
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;

    // maxWidth/imageQuality downscale client-side so a typical phone photo
    // doesn't need to hit the backend's 2MB limit to begin with — most
    // picks succeed without ever bumping into that validation.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    setState(() => _isUploadingPhoto = true);
    final result = await ProfilePhotoService.instance.upload(File(picked.path));
    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);

    if (result.unauthorized) {
      _logout();
      return;
    }

    if (result.success) {
      // Re-fetches the whole employee record rather than patching photoUrl
      // locally — EmployeeState is shared via Provider, so this is also
      // what keeps Beranda (and anywhere else that reads it later) in sync
      // without a restart.
      await context.read<EmployeeState>().fetchMe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Gagal mengunggah foto.')),
      );
    }
  }

  void _logout() {
    context.read<EmployeeState>().clear();
    context.read<ActivityState>().clear();
    context.read<PointsState>().clear();
    context.read<LeaderboardState>().clear();
    context.read<HistoryState>().clear();
    context.read<WalkSessionState>().clear();
    context.read<MonitoringState>().clear();
    context.read<EmployeeDetailState>().clear();
    context.read<AppState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final employeeState = context.watch<EmployeeState>();
    final employee = employeeState.employee;
    final points = context.watch<PointsState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          if (employeeState.isLoading && employee == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 44),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (employee == null && employeeState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 28,
                    color: AppColors.mut,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    employeeState.error!,
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 12.5, color: AppColors.mut),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.read<EmployeeState>().fetchMe(),
                    child: Text(
                      'Coba lagi',
                      style: AppText.body(size: 13, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: _isUploadingPhoto ? 0.5 : 1,
                    child: Avatar(
                      initials: employee?.initials ?? '?',
                      imageUrl: employee?.photoUrl,
                      size: 82,
                      fontSize: 32,
                      borderColor: AppColors.accent,
                      textColor: AppColors.accent,
                    ),
                  ),
                  if (_isUploadingPhoto)
                    const Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bg, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 13, color: Color(0xFF06231A)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(employee?.fullName ?? '—', style: AppText.heading(size: 22)),
            const SizedBox(height: 2),
            Text(
              '${employee?.divisionName ?? '—'} · ID ${employee?.employeeCode ?? '—'}',
              style: AppText.body(size: 12.5, color: AppColors.mut),
            ),
          ],
          const SizedBox(height: 22),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _stat(
                  _fmt(points.totalPoints),
                  'Total poin',
                  AppColors.violet,
                  border: true,
                ),
                _stat('6', 'Lencana', AppColors.amberSoft, border: true),
                _stat('182', 'km total', AppColors.accent, border: false),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => appState.go(AppScreen.badge),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.amberTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      size: 20,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pencapaian & Lencana',
                          style: AppText.body(
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '6 diraih · 3 dalam proses',
                          style: AppText.body(size: 11.5, color: AppColors.mut),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.dim,
                  ),
                ],
              ),
            ),
          ),
          const SectionLabel(
            'Pengaturan',
            padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                _settingRow(
                  icon: Icons.favorite,
                  iconColor: AppColors.accent,
                  title: 'Health Connect',
                  subtitle: 'Sinkron otomatis langkah & jarak',
                  onTap: _healthConnected ? null : _connectHealthConnect,
                  trailing: _healthConnected
                      ? const PillTag(
                          text: 'Tersambung',
                          color: AppColors.accent,
                          background: AppColors.accentTint,
                          icon: Icons.check,
                        )
                      : const PillTag(
                          text: 'Belum tersambung',
                          color: AppColors.mut,
                          background: AppColors.card2,
                        ),
                ),
                // Not backed by any setting yet — always shown in a
                // visually disabled (not tappable-looking) state so it
                // doesn't read as a broken control. Un-mute once there's a
                // real notification preference to toggle.
                _settingRow(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.dim,
                  title: 'Notifikasi',
                  subtitle: 'Segera hadir',
                  trailing: Container(
                    width: 42,
                    height: 24,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.dim,
                      ),
                    ),
                  ),
                ),
                // Same as above — no language-switching feature behind
                // this yet, so no chevron (nothing to navigate into) and
                // muted throughout.
                _settingRow(
                  icon: Icons.language,
                  iconColor: AppColors.dim,
                  title: 'Bahasa',
                  subtitle: 'Segera hadir',
                  trailing: Text(
                    'Indonesia',
                    style: AppText.body(size: 12.5, color: AppColors.dim),
                  ),
                ),
                GestureDetector(
                  onTap: _logout,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout,
                          size: 19,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Keluar',
                            style: AppText.body(
                              size: 14,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Image.asset('assets/images/logo-bbm.png', height: 36),
                const SizedBox(height: 8),
                Text(
                  'Program Budaya Hidup Sehat · PT BBM',
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 10.5, color: AppColors.mut),
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

  Widget _stat(
    String value,
    String label,
    Color color, {
    required bool border,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        border: border
            ? const Border(right: BorderSide(color: AppColors.line))
            : null,
      ),
      child: Column(
        children: [
          Text(value, style: AppText.num(size: 22, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppText.body(size: 10.5, color: AppColors.mut)),
        ],
      ),
    ),
  );

  Widget _settingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(size: 14)),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: AppText.body(size: 11.5, color: AppColors.mut),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );

    if (onTap == null) return row;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}
