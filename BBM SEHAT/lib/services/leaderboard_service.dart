import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/leaderboard_my_position.dart';
import '../models/models.dart';
import 'auth_service.dart';

enum LeaderboardScope {
  ownDivision('own_division'),
  allEmployees('all_employees'),
  byDivision('by_division');

  final String apiValue;
  const LeaderboardScope(this.apiValue);
}

enum LeaderboardPeriod {
  weekly('weekly'),
  monthly('monthly');

  final String apiValue;
  const LeaderboardPeriod(this.apiValue);
}

class LeaderboardResult {
  final List<LeaderboardEntry>? entries;
  final bool unauthorized;
  final String? errorMessage;

  const LeaderboardResult.success(List<LeaderboardEntry> this.entries)
      : unauthorized = false,
        errorMessage = null;

  const LeaderboardResult.unauthorized()
      : entries = null,
        unauthorized = true,
        errorMessage = null;

  const LeaderboardResult.failure(this.errorMessage)
      : entries = null,
        unauthorized = false;
}

class MyPositionResult {
  final LeaderboardMyPosition? position;
  final bool unauthorized;
  final String? errorMessage;

  const MyPositionResult.success(LeaderboardMyPosition this.position)
      : unauthorized = false,
        errorMessage = null;

  const MyPositionResult.unauthorized()
      : position = null,
        unauthorized = true,
        errorMessage = null;

  const MyPositionResult.failure(this.errorMessage)
      : position = null,
        unauthorized = false;
}

/// Talks to GET /api/leaderboard and GET /api/leaderboard/my-position.
/// Reuses AuthService's stored token rather than managing its own — there's
/// only ever one signed-in employee.
class LeaderboardService {
  LeaderboardService._internal();
  static final LeaderboardService instance = LeaderboardService._internal();

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

  Future<LeaderboardResult> fetchLeaderboard({
    required LeaderboardScope scope,
    required LeaderboardPeriod period,
  }) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const LeaderboardResult.unauthorized();

    try {
      final response = await _dio.get(
        '/leaderboard',
        queryParameters: {'scope': scope.apiValue, 'period': period.apiValue},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final json = response.data['data'] as Map<String, dynamic>;
      final entries = (json['entries'] as List)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return LeaderboardResult.success(entries);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const LeaderboardResult.unauthorized();

      return LeaderboardResult.failure(_messageFor(e));
    }
  }

  Future<MyPositionResult> fetchMyPosition({
    required LeaderboardScope scope,
    required LeaderboardPeriod period,
  }) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const MyPositionResult.unauthorized();

    try {
      final response = await _dio.get(
        '/leaderboard/my-position',
        queryParameters: {'scope': scope.apiValue, 'period': period.apiValue},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final json = response.data['data'] as Map<String, dynamic>;
      return MyPositionResult.success(LeaderboardMyPosition.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const MyPositionResult.unauthorized();

      return MyPositionResult.failure(_messageFor(e));
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

    return 'Gagal memuat papan peringkat.';
  }
}
