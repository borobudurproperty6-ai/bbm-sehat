import 'package:flutter/material.dart';
import '../models/monitoring.dart';
import '../services/monitoring_service.dart';

/// Company-wide monitoring dashboard data (GET /api/monitoring/*) — only
/// ever fetched by MonitoringScreen, which is only reachable for roles that
/// pass BbmBottomNavBar's role check (management/super_admin/admin_umum_sdm),
/// matching the same gate the backend itself enforces (MONITORING_API.md).
class MonitoringState extends ChangeNotifier {
  MonitoringOverview? overview;
  bool isLoadingOverview = false;
  String? overviewError;

  List<DivisionMonitoringEntry> divisions = [];
  bool isLoadingDivisions = false;
  String? divisionsError;

  List<InactiveEmployee> inactiveEmployees = [];
  int inactiveDays = 7;
  bool isLoadingInactive = false;
  String? inactiveError;

  // "Progres Karyawan" section — paginated, appended to on scroll rather
  // than fetched all at once (48+ employees).
  List<EmployeeListItem> employeeList = [];
  String employeeSearch = '';
  EmployeeSortBy employeeSortBy = EmployeeSortBy.poin;
  bool isLoadingEmployees = false;
  bool isLoadingMoreEmployees = false;
  String? employeesError;
  int _employeesCurrentPage = 1;
  int _employeesLastPage = 1;
  bool get hasMoreEmployees => _employeesCurrentPage < _employeesLastPage;

  bool sessionExpired = false;
  // True if the backend itself rejected the role (403) — distinct from a
  // network/server error, and from sessionExpired (401). Shouldn't normally
  // happen since the tab is only shown for qualifying roles in the first
  // place, but a stale role cached client-side while it changed server-side
  // must show a clear message, not a generic "gagal memuat" or a crash.
  bool forbidden = false;

  Future<void> fetchOverview() async {
    isLoadingOverview = true;
    overviewError = null;
    notifyListeners();

    final result = await MonitoringService.instance.fetchOverview();

    isLoadingOverview = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.forbidden) {
      forbidden = true;
    } else if (result.overview != null) {
      overview = result.overview;
    } else {
      overviewError = result.errorMessage ?? 'Gagal memuat ringkasan.';
    }
    notifyListeners();
  }

  Future<void> fetchPerDivisi() async {
    isLoadingDivisions = true;
    divisionsError = null;
    notifyListeners();

    final result = await MonitoringService.instance.fetchPerDivisi();

    isLoadingDivisions = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.forbidden) {
      forbidden = true;
    } else if (result.divisions != null) {
      divisions = result.divisions!;
    } else {
      divisionsError = result.errorMessage ?? 'Gagal memuat data per divisi.';
    }
    notifyListeners();
  }

  /// [days] defaults to whatever was last selected (starts at 7) — pass an
  /// explicit value when the user picks a different option in the UI.
  Future<void> fetchTidakAktif({int? days}) async {
    if (days != null) inactiveDays = days;

    isLoadingInactive = true;
    inactiveError = null;
    notifyListeners();

    final result = await MonitoringService.instance.fetchTidakAktif(days: inactiveDays);

    isLoadingInactive = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.forbidden) {
      forbidden = true;
    } else if (result.employees != null) {
      inactiveEmployees = result.employees!;
    } else {
      inactiveError = result.errorMessage ?? 'Gagal memuat daftar karyawan tidak aktif.';
    }
    notifyListeners();
  }

  /// Fresh load (page 1, replacing whatever's in [employeeList]) — called
  /// on first entering the section, and whenever [search]/[sortBy] change.
  /// Pass explicit values (rather than mutating employeeSearch/employeeSortBy
  /// directly first) so a caller can't forget to reset the page.
  Future<void> fetchEmployees({String? search, EmployeeSortBy? sortBy}) async {
    if (search != null) employeeSearch = search;
    if (sortBy != null) employeeSortBy = sortBy;

    isLoadingEmployees = true;
    employeesError = null;
    notifyListeners();

    final result = await MonitoringService.instance.fetchEmployees(
      search: employeeSearch,
      sortBy: employeeSortBy,
      page: 1,
    );

    isLoadingEmployees = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.forbidden) {
      forbidden = true;
    } else if (result.employees != null) {
      employeeList = result.employees!;
      _employeesCurrentPage = result.currentPage!;
      _employeesLastPage = result.lastPage!;
    } else {
      employeesError = result.errorMessage ?? 'Gagal memuat daftar karyawan.';
    }
    notifyListeners();
  }

  /// Infinite-scroll continuation — appends the next page rather than
  /// replacing [employeeList]. No-op if already loading or already on the
  /// last page, so a scroll listener can call this liberally without its
  /// own guard.
  Future<void> loadMoreEmployees() async {
    if (isLoadingMoreEmployees || isLoadingEmployees || !hasMoreEmployees) return;

    isLoadingMoreEmployees = true;
    notifyListeners();

    final result = await MonitoringService.instance.fetchEmployees(
      search: employeeSearch,
      sortBy: employeeSortBy,
      page: _employeesCurrentPage + 1,
    );

    isLoadingMoreEmployees = false;
    if (result.unauthorized) {
      sessionExpired = true;
    } else if (result.forbidden) {
      forbidden = true;
    } else if (result.employees != null) {
      employeeList = [...employeeList, ...result.employees!];
      _employeesCurrentPage = result.currentPage!;
      _employeesLastPage = result.lastPage!;
    }
    // A failed "load more" leaves the existing list intact and simply
    // doesn't advance the page — the user can trigger another attempt by
    // scrolling again, no separate error UI needed for this case.
    notifyListeners();
  }

  Future<void> fetchAll() async {
    await Future.wait([
      fetchOverview(),
      fetchPerDivisi(),
      fetchTidakAktif(),
      fetchEmployees(),
    ]);
  }

  void clear() {
    overview = null;
    isLoadingOverview = false;
    overviewError = null;
    divisions = [];
    isLoadingDivisions = false;
    divisionsError = null;
    inactiveEmployees = [];
    inactiveDays = 7;
    isLoadingInactive = false;
    employeeList = [];
    employeeSearch = '';
    employeeSortBy = EmployeeSortBy.poin;
    isLoadingEmployees = false;
    isLoadingMoreEmployees = false;
    employeesError = null;
    _employeesCurrentPage = 1;
    _employeesLastPage = 1;
    inactiveError = null;
    sessionExpired = false;
    forbidden = false;
    notifyListeners();
  }
}
