import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class WalkReminderResult {
  final bool success;
  final int? sentCount;
  final int? skippedNoDeviceCount;
  final int? failedCount;
  final bool unauthorized;
  final bool forbidden;
  final String? errorMessage;

  const WalkReminderResult.success({
    required this.sentCount,
    required this.skippedNoDeviceCount,
    required this.failedCount,
  })  : success = true,
        unauthorized = false,
        forbidden = false,
        errorMessage = null;

  const WalkReminderResult.unauthorized()
      : success = false,
        sentCount = null,
        skippedNoDeviceCount = null,
        failedCount = null,
        unauthorized = true,
        forbidden = false,
        errorMessage = null;

  const WalkReminderResult.forbidden()
      : success = false,
        sentCount = null,
        skippedNoDeviceCount = null,
        failedCount = null,
        unauthorized = false,
        forbidden = true,
        errorMessage = null;

  const WalkReminderResult.failure(this.errorMessage)
      : success = false,
        sentCount = null,
        skippedNoDeviceCount = null,
        failedCount = null,
        unauthorized = false,
        forbidden = false;
}

/// Talks to POST /api/admin/send-walk-reminder — role-gated backend-side to
/// SUPER_ADMIN/ADMIN_UMUM_SDM (narrower than the Monitoring dashboard's own
/// role set, deliberately excluding MANAGEMENT for this action).
class WalkReminderService {
  WalkReminderService._internal();
  static final WalkReminderService instance = WalkReminderService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    // Sending pushes to every below-target employee one at a time on the
    // backend can take a few seconds longer than a typical read — give it
    // more room than the default before treating it as a timeout.
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Connection': 'close'},
  ));

  Future<WalkReminderResult> send() async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const WalkReminderResult.unauthorized();

    try {
      final response = await _dio.post(
        '/admin/send-walk-reminder',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return WalkReminderResult.success(
        sentCount: data['sent_count'] as int,
        skippedNoDeviceCount: data['skipped_no_device_count'] as int,
        failedCount: data['failed_count'] as int,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const WalkReminderResult.unauthorized();
      if (e.response?.statusCode == 403) return const WalkReminderResult.forbidden();

      return WalkReminderResult.failure(_messageFor(e));
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

    return 'Gagal mengirim reminder.';
  }
}
