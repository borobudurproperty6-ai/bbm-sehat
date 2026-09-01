import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

/// Talks to POST /api/devices/register (DeviceTokenController on the
/// backend). Every call is best-effort — a push token that fails to reach
/// the backend must never block login or any other flow, so failures are
/// only logged, never thrown. The device just won't receive push
/// notifications until the next successful registration attempt (next app
/// open, or the next FirebaseMessaging.onTokenRefresh).
class DeviceTokenService {
  DeviceTokenService._internal();
  static final DeviceTokenService instance = DeviceTokenService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    headers: {'Connection': 'close'},
  ));

  Future<void> register(String fcmToken) async {
    final authToken = await AuthService.instance.readToken();
    if (authToken == null || authToken.isEmpty) {
      debugPrint('DeviceTokenService: belum ada sesi login, lewati registrasi token FCM.');
      return;
    }

    try {
      final response = await _dio.post(
        '/devices/register',
        data: {'fcm_token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
      debugPrint('DeviceTokenService: token FCM berhasil didaftarkan ke backend. status=${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('DeviceTokenService: gagal mendaftarkan token FCM — ${e.message} status=${e.response?.statusCode}');
    }
  }
}
