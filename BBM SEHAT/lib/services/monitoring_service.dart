import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/monitoring.dart';
import 'auth_service.dart';

class MonitoringOverviewResult {
  final MonitoringOverview? overview;
  final bool unauthorized;
  final bool forbidden;
  final String? errorMessage;

  const MonitoringOverviewResult.success(MonitoringOverview this.overview)
      : unauthorized = false,
        forbidden = false,
        errorMessage = null;

  const MonitoringOverviewResult.unauthorized()
      : overview = null,
        unauthorized = true,
        forbidden = false,
        errorMessage = null;

  const MonitoringOverviewResult.forbidden()
      : overview = null,
        unauthorized = false,
        forbidden = true,
        errorMessage = null;

  const MonitoringOverviewResult.failure(this.errorMessage)
      : overview = null,
        unauthorized = false,
        forbidden = false;
}

class MonitoringPerDivisiResult {
  final List<DivisionMonitoringEntry>? divisions;
  final bool unauthorized;
  final bool forbidden;
  final String? errorMessage;

  const MonitoringPerDivisiResult.success(List<DivisionMonitoringEntry> this.divisions)
      : unauthorized = false,
        forbidden = false,
        errorMessage = null;

  const MonitoringPerDivisiResult.unauthorized()
      : divisions = null,
        unauthorized = true,
        forbidden = false,
        errorMessage = null;

  const MonitoringPerDivisiResult.forbidden()
      : divisions = null,
        unauthorized = false,
        forbidden = true,
        errorMessage = null;

  const MonitoringPerDivisiResult.failure(this.errorMessage)
      : divisions = null,
        unauthorized = false,
        forbidden = false;
}

class MonitoringTidakAktifResult {
  final List<InactiveEmployee>? employees;
  final bool unauthorized;
  final bool forbidden;
  final String? errorMessage;

  const MonitoringTidakAktifResult.success(List<InactiveEmployee> this.employees)
      : unauthorized = false,
        forbidden = false,
        errorMessage = null;

  const MonitoringTidakAktifResult.unauthorized()
      : employees = null,
        unauthorized = true,
        forbidden = false,
        errorMessage = null;

  const MonitoringTidakAktifResult.forbidden()
      : employees = null,
        unauthorized = false,
        forbidden = true,
        errorMessage = null;

  const MonitoringTidakAktifResult.failure(this.errorMessage)
      : employees = null,
        unauthorized = false,
        forbidden = false;
}

class EmployeeListResult {
  final List<EmployeeListItem>? employees;
  final int? currentPage;
  final int? lastPage;
  final bool unauthorized;
  final bool forbidden;
  final String? errorMessage;

  const EmployeeListResult.success(List<EmployeeListItem> this.employees, this.currentPage, this.lastPage)
      : unauthorized = false,
        forbidden = false,
        errorMessage = null;

  const EmployeeListResult.unauthorized()
      : employees = null,
        currentPage = null,
        lastPage = null,
        unauthorized = true,
        forbidden = false,
        errorMessage = null;

  const EmployeeListResult.forbidden()
      : employees = null,
        currentPage = null,
        lastPage = null,
        unauthorized = false,
        forbidden = true,
        errorMessage = null;

  const EmployeeListResult.failure(this.errorMessage)
      : employees = null,
        currentPage = null,
        lastPage = null,
        unauthorized = false,
        forbidden = false;
}

class EmployeeDetailResult {
  final EmployeeMonitoringDetail? detail;
  final bool unauthorized;
  final bool forbidden;
  final bool notFound;
  final String? errorMessage;

  const EmployeeDetailResult.success(EmployeeMonitoringDetail this.detail)
      : unauthorized = false,
        forbidden = false,
        notFound = false,
        errorMessage = null;

  const EmployeeDetailResult.unauthorized()
      : detail = null,
        unauthorized = true,
        forbidden = false,
        notFound = false,
        errorMessage = null;

  const EmployeeDetailResult.forbidden()
      : detail = null,
        unauthorized = false,
        forbidden = true,
        notFound = false,
        errorMessage = null;

  const EmployeeDetailResult.notFoundResult()
      : detail = null,
        unauthorized = false,
        forbidden = false,
        notFound = true,
        errorMessage = null;

  const EmployeeDetailResult.failure(this.errorMessage)
      : detail = null,
        unauthorized = false,
        forbidden = false,
        notFound = false;
}

/// Talks to GET /api/monitoring/* (see MONITORING_API.md). These are
/// role-gated backend-side — this app only ever calls them when the
/// logged-in employee's roleCode already qualifies (see MonitoringState /
/// BbmBottomNavBar's role check), so a 403 here would mean the employee's
/// role changed server-side mid-session, not a normal flow.
class MonitoringService {
  MonitoringService._internal();
  static final MonitoringService instance = MonitoringService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    headers: {'Connection': 'close'},
  ));

  @visibleForTesting
  static void debugConfigureDio(void Function(Dio dio) configure) {
    configure(instance._dio);
  }

  Future<MonitoringOverviewResult> fetchOverview() async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const MonitoringOverviewResult.unauthorized();

    try {
      final response = await _dio.get(
        '/monitoring/overview',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return MonitoringOverviewResult.success(
        MonitoringOverview.fromJson(response.data['data'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const MonitoringOverviewResult.unauthorized();
      if (e.response?.statusCode == 403) return const MonitoringOverviewResult.forbidden();

      return MonitoringOverviewResult.failure(_messageFor(e));
    }
  }

  Future<MonitoringPerDivisiResult> fetchPerDivisi() async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const MonitoringPerDivisiResult.unauthorized();

    try {
      final response = await _dio.get(
        '/monitoring/per-divisi',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final json = response.data['data'] as Map<String, dynamic>;
      final divisions = (json['divisions'] as List)
          .map((e) => DivisionMonitoringEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return MonitoringPerDivisiResult.success(divisions);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const MonitoringPerDivisiResult.unauthorized();
      if (e.response?.statusCode == 403) return const MonitoringPerDivisiResult.forbidden();

      return MonitoringPerDivisiResult.failure(_messageFor(e));
    }
  }

  Future<MonitoringTidakAktifResult> fetchTidakAktif({int days = 7}) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const MonitoringTidakAktifResult.unauthorized();

    try {
      final response = await _dio.get(
        '/monitoring/tidak-aktif',
        queryParameters: {'days': days},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final json = response.data['data'] as Map<String, dynamic>;
      final employees = (json['employees'] as List)
          .map((e) => InactiveEmployee.fromJson(e as Map<String, dynamic>))
          .toList();
      return MonitoringTidakAktifResult.success(employees);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const MonitoringTidakAktifResult.unauthorized();
      if (e.response?.statusCode == 403) return const MonitoringTidakAktifResult.forbidden();

      return MonitoringTidakAktifResult.failure(_messageFor(e));
    }
  }

  Future<EmployeeListResult> fetchEmployees({
    String? search,
    EmployeeSortBy sortBy = EmployeeSortBy.poin,
    int? divisionId,
    int page = 1,
    int perPage = 20,
  }) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const EmployeeListResult.unauthorized();

    try {
      final response = await _dio.get(
        '/monitoring/employees',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'sort_by': sortBy.apiValue,
          'divisi': ?divisionId,
          'page': page,
          'per_page': perPage,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final employees = (response.data['data'] as List)
          .map((e) => EmployeeListItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = response.data['meta'] as Map<String, dynamic>;
      return EmployeeListResult.success(employees, meta['current_page'] as int, meta['last_page'] as int);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const EmployeeListResult.unauthorized();
      if (e.response?.statusCode == 403) return const EmployeeListResult.forbidden();

      return EmployeeListResult.failure(_messageFor(e));
    }
  }

  Future<EmployeeDetailResult> fetchEmployeeDetail(int employeeId) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const EmployeeDetailResult.unauthorized();

    try {
      final response = await _dio.get(
        '/monitoring/employees/$employeeId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return EmployeeDetailResult.success(
        EmployeeMonitoringDetail.fromJson(response.data['data'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const EmployeeDetailResult.unauthorized();
      if (e.response?.statusCode == 403) return const EmployeeDetailResult.forbidden();
      if (e.response?.statusCode == 404) return const EmployeeDetailResult.notFoundResult();

      return EmployeeDetailResult.failure(_messageFor(e));
    }
  }

  String _messageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return 'Tidak bisa terhubung ke server, cek koneksi.';
      default:
        break;
    }

    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }

    return 'Gagal memuat data monitoring.';
  }
}
