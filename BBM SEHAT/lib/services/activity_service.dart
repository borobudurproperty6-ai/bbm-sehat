import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/activity_history.dart';
import '../models/daily_activity.dart';
import 'auth_service.dart';

enum HistoryPeriod {
  weekly('weekly'),
  monthly('monthly');

  final String apiValue;
  const HistoryPeriod(this.apiValue);
}

class ActivityHistoryResult {
  final ActivityHistory? history;
  final bool unauthorized;
  final String? errorMessage;

  const ActivityHistoryResult.success(ActivityHistory this.history)
      : unauthorized = false,
        errorMessage = null;

  const ActivityHistoryResult.unauthorized()
      : history = null,
        unauthorized = true,
        errorMessage = null;

  const ActivityHistoryResult.failure(this.errorMessage)
      : history = null,
        unauthorized = false;
}

class TodayActivityResult {
  final DailyActivity? activity;
  final bool unauthorized;
  final String? errorMessage;

  const TodayActivityResult.success(DailyActivity this.activity)
      : unauthorized = false,
        errorMessage = null;

  const TodayActivityResult.unauthorized()
      : activity = null,
        unauthorized = true,
        errorMessage = null;

  const TodayActivityResult.failure(this.errorMessage)
      : activity = null,
        unauthorized = false;
}

class SyncOutcome {
  final bool success;
  final bool unauthorized;
  final String? errorMessage;

  const SyncOutcome.success()
      : success = true,
        unauthorized = false,
        errorMessage = null;

  const SyncOutcome.unauthorized()
      : success = false,
        unauthorized = true,
        errorMessage = null;

  const SyncOutcome.failure(this.errorMessage)
      : success = false,
        unauthorized = false;
}

/// Talks to the step-sync endpoints. Reuses AuthService's stored token
/// rather than managing its own — there's only ever one signed-in employee.
class ActivityService {
  ActivityService._internal();
  static final ActivityService instance = ActivityService._internal();

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

  Future<TodayActivityResult> fetchToday() async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const TodayActivityResult.unauthorized();

    try {
      final response = await _dio.get(
        '/activity/today',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final json = response.data['data'] as Map<String, dynamic>;
      return TodayActivityResult.success(DailyActivity.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const TodayActivityResult.unauthorized();

      return TodayActivityResult.failure(_messageFor(e));
    }
  }

  /// Sends today's date automatically — this endpoint only ever syncs
  /// "today" from the app's point of view.
  Future<SyncOutcome> syncToday({required int steps, double? distanceMeters}) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const SyncOutcome.unauthorized();

    final now = DateTime.now();
    final activityDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      await _dio.post(
        '/activity/sync',
        data: {
          'activity_date': activityDate,
          'steps': steps,
          'distance_meters': ?distanceMeters,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return const SyncOutcome.success();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const SyncOutcome.unauthorized();

      return SyncOutcome.failure(_messageFor(e));
    }
  }

  Future<ActivityHistoryResult> fetchHistory(HistoryPeriod period) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const ActivityHistoryResult.unauthorized();

    try {
      final response = await _dio.get(
        '/activity/history',
        queryParameters: {'period': period.apiValue},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final json = response.data['data'] as Map<String, dynamic>;
      return ActivityHistoryResult.success(ActivityHistory.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const ActivityHistoryResult.unauthorized();

      return ActivityHistoryResult.failure(_messageFor(e));
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

    return 'Gagal memuat data aktivitas.';
  }
}
