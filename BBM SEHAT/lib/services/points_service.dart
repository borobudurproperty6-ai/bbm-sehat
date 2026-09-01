import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/points_summary.dart';
import 'auth_service.dart';

class PointsSummaryResult {
  final PointsSummary? summary;
  final bool unauthorized;
  final String? errorMessage;

  const PointsSummaryResult.success(PointsSummary this.summary)
      : unauthorized = false,
        errorMessage = null;

  const PointsSummaryResult.unauthorized()
      : summary = null,
        unauthorized = true,
        errorMessage = null;

  const PointsSummaryResult.failure(this.errorMessage)
      : summary = null,
        unauthorized = false;
}

/// Talks to GET /api/points/summary. Reuses AuthService's stored token
/// rather than managing its own — there's only ever one signed-in employee.
class PointsService {
  PointsService._internal();
  static final PointsService instance = PointsService._internal();

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

  Future<PointsSummaryResult> fetchSummary() async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const PointsSummaryResult.unauthorized();

    try {
      final response = await _dio.get(
        '/points/summary',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final json = response.data['data'] as Map<String, dynamic>;
      return PointsSummaryResult.success(PointsSummary.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const PointsSummaryResult.unauthorized();

      return PointsSummaryResult.failure(_messageFor(e));
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

    return 'Gagal memuat data poin.';
  }
}
