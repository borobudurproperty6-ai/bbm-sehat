import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/employee.dart';
import 'token_storage.dart';

class LoginOutcome {
  final bool success;
  final bool mustChangePassword;
  final String? errorMessage;

  const LoginOutcome.success({required this.mustChangePassword})
      : success = true,
        errorMessage = null;

  const LoginOutcome.failure(this.errorMessage)
      : success = false,
        mustChangePassword = false;
}

class MeResult {
  final Employee? employee;
  final bool unauthorized;
  final String? errorMessage;

  const MeResult.success(Employee this.employee)
      : unauthorized = false,
        errorMessage = null;

  const MeResult.unauthorized()
      : employee = null,
        unauthorized = true,
        errorMessage = null;

  const MeResult.failure(this.errorMessage)
      : employee = null,
        unauthorized = false;
}

/// Talks to the Laravel backend's auth endpoints and holds the Sanctum
/// bearer token in encrypted storage (flutter_secure_storage) — never in
/// plain SharedPreferences.
class AuthService {
  AuthService._internal() : _storage = const SecureTokenStorage();
  static final AuthService instance = AuthService._internal();

  /// Test-only escape hatch: swap in an in-memory TokenStorage so the real
  /// login flow can be driven against a real backend under `flutter test`,
  /// which has no native platform to back flutter_secure_storage's channel.
  @visibleForTesting
  static void debugOverrideStorage(TokenStorage storage) {
    instance._storage = storage;
  }

  /// Test-only escape hatch: lets a test reach into the Dio instance (e.g.
  /// to tweak dart:io connection pooling) without AuthService itself
  /// importing dart:io — that import doesn't exist on the web target, which
  /// is where this app is normally run.
  @visibleForTesting
  static void debugConfigureDio(void Function(Dio dio) configure) {
    configure(instance._dio);
  }

  // Connection: close avoids keeping a pooled socket around between
  // requests — mobile networks drop/switch connections often enough
  // (sleep, wifi<->cellular) that a fresh connection per request is more
  // robust than reusing one that may have gone stale.
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    headers: {'Connection': 'close'},
  ));

  TokenStorage _storage;
  static const _tokenKey = 'bbm_sehat_auth_token';

  Future<String?> readToken() => _storage.read(_tokenKey);

  Future<void> _saveToken(String token) => _storage.write(_tokenKey, token);

  Future<void> clearToken() => _storage.delete(_tokenKey);

  Future<LoginOutcome> login(String employeeCode, String password) async {
    try {
      final response = await _dio.post('/login', data: {
        'employee_code': employeeCode,
        'password': password,
      });

      final token = response.data['token'] as String;
      final mustChange = response.data['must_change_password'] as bool? ?? false;
      await _saveToken(token);

      return LoginOutcome.success(mustChangePassword: mustChange);
    } on DioException catch (e) {
      return LoginOutcome.failure(_messageFor(e));
    }
  }

  /// Returns null on success, or an error message to show the user.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await readToken();
    try {
      await _dio.post(
        '/change-password',
        data: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return null;
    } on DioException catch (e) {
      return _messageFor(e);
    }
  }

  Future<MeResult> fetchMe() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return const MeResult.unauthorized();

    try {
      final response = await _dio.get(
        '/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final json = response.data['data'] as Map<String, dynamic>;
      return MeResult.success(Employee.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const MeResult.unauthorized();

      return MeResult.failure(_messageFor(e));
    }
  }

  /// True if a token is stored and the backend still accepts it.
  Future<bool> hasValidSession() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await _dio.get(
        '/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  Future<void> logout() async {
    final token = await readToken();
    try {
      await _dio.post(
        '/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException {
      // Best-effort — clear the local token regardless of server outcome.
    }
    await clearToken();
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

    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (status == 429) {
      return 'Terlalu banyak percobaan, coba lagi beberapa saat lagi.';
    }

    if (status == 422 && data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final firstList = errors.values.firstOrNull;
      if (firstList is List && firstList.isNotEmpty) {
        return firstList.first.toString();
      }
    }

    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }

    return 'Terjadi kesalahan. Coba lagi.';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
