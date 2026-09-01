import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/walk_session.dart';
import 'auth_service.dart';

class StartSessionResult {
  final int? sessionId;
  final bool unauthorized;
  final String? errorMessage;

  const StartSessionResult.success(int this.sessionId)
      : unauthorized = false,
        errorMessage = null;

  const StartSessionResult.unauthorized()
      : sessionId = null,
        unauthorized = true,
        errorMessage = null;

  const StartSessionResult.failure(this.errorMessage)
      : sessionId = null,
        unauthorized = false;
}

class FinishSessionResult {
  final WalkSession? session;
  final bool unauthorized;
  final String? errorMessage;

  const FinishSessionResult.success(WalkSession this.session)
      : unauthorized = false,
        errorMessage = null;

  const FinishSessionResult.unauthorized()
      : session = null,
        unauthorized = true,
        errorMessage = null;

  const FinishSessionResult.failure(this.errorMessage)
      : session = null,
        unauthorized = false;
}

class DiscardSessionResult {
  final bool success;
  final bool unauthorized;
  final String? errorMessage;

  const DiscardSessionResult.success()
      : success = true,
        unauthorized = false,
        errorMessage = null;

  const DiscardSessionResult.unauthorized()
      : success = false,
        unauthorized = true,
        errorMessage = null;

  const DiscardSessionResult.failure(this.errorMessage)
      : success = false,
        unauthorized = false;
}

class SessionListResult {
  final List<WalkSession>? sessions;
  final bool unauthorized;
  final String? errorMessage;

  const SessionListResult.success(List<WalkSession> this.sessions)
      : unauthorized = false,
        errorMessage = null;

  const SessionListResult.unauthorized()
      : sessions = null,
        unauthorized = true,
        errorMessage = null;

  const SessionListResult.failure(this.errorMessage)
      : sessions = null,
        unauthorized = false;
}

/// Talks to /api/walk-sessions/*. Reuses AuthService's stored token rather
/// than managing its own — there's only ever one signed-in employee.
class WalkSessionService {
  WalkSessionService._internal();
  static final WalkSessionService instance = WalkSessionService._internal();

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

  Future<StartSessionResult> start({required double startLat, required double startLng}) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const StartSessionResult.unauthorized();

    try {
      final response = await _dio.post(
        '/walk-sessions/start',
        data: {'start_lat': startLat, 'start_lng': startLng},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final json = response.data['data'] as Map<String, dynamic>;
      return StartSessionResult.success(json['id'] as int);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const StartSessionResult.unauthorized();

      return StartSessionResult.failure(_messageFor(e));
    }
  }

  Future<FinishSessionResult> finish({
    required int sessionId,
    required double endLat,
    required double endLng,
    required int durationSeconds,
    required List<RoutePoint> points,
  }) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const FinishSessionResult.unauthorized();

    try {
      final response = await _dio.patch(
        '/walk-sessions/$sessionId/finish',
        data: {
          'end_lat': endLat,
          'end_lng': endLng,
          'duration_seconds': durationSeconds,
          'points': points.map((p) => p.toJson()).toList(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final json = response.data['data'] as Map<String, dynamic>;
      return FinishSessionResult.success(WalkSession.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const FinishSessionResult.unauthorized();

      return FinishSessionResult.failure(_messageFor(e));
    }
  }

  /// "Hapus" on the session-summary screen — finish() already saved the
  /// session and awarded points, so this has to undo both server-side, not
  /// just reset the local UI.
  Future<DiscardSessionResult> discard(int sessionId) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const DiscardSessionResult.unauthorized();

    try {
      await _dio.delete(
        '/walk-sessions/$sessionId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return const DiscardSessionResult.success();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const DiscardSessionResult.unauthorized();

      return DiscardSessionResult.failure(_messageFor(e));
    }
  }

  Future<SessionListResult> list() async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const SessionListResult.unauthorized();

    try {
      final response = await _dio.get(
        '/walk-sessions',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final sessions = (response.data['data'] as List)
          .map((e) => WalkSession.fromJson(e as Map<String, dynamic>))
          .toList();
      return SessionListResult.success(sessions);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const SessionListResult.unauthorized();

      return SessionListResult.failure(_messageFor(e));
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

    return 'Gagal menyimpan sesi jalan kaki.';
  }
}
