import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ProfilePhotoResult {
  final bool success;
  final String? photoUrl;
  final bool unauthorized;
  final String? errorMessage;

  const ProfilePhotoResult.success(this.photoUrl)
      : success = true,
        unauthorized = false,
        errorMessage = null;

  const ProfilePhotoResult.unauthorized()
      : success = false,
        photoUrl = null,
        unauthorized = true,
        errorMessage = null;

  const ProfilePhotoResult.failure(this.errorMessage)
      : success = false,
        photoUrl = null,
        unauthorized = false;
}

/// Talks to POST /api/profile/photo — every logged-in employee can upload
/// their own photo (no role gate), matching the backend's plain
/// auth:sanctum route.
class ProfilePhotoService {
  ProfilePhotoService._internal();
  static final ProfilePhotoService instance = ProfilePhotoService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    // A multipart upload over a slow connection needs more room than a
    // typical JSON request before this is treated as a timeout.
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Connection': 'close'},
  ));

  Future<ProfilePhotoResult> upload(File photo) async {
    final token = await AuthService.instance.readToken();
    if (token == null || token.isEmpty) return const ProfilePhotoResult.unauthorized();

    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photo.path, filename: photo.path.split('/').last),
      });
      final response = await _dio.post(
        '/profile/photo',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final rawUrl = data['photo_url'] as String?;
      return ProfilePhotoResult.success(rawUrl != null ? ApiConfig.resolveAssetUrl(rawUrl) : null);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const ProfilePhotoResult.unauthorized();

      return ProfilePhotoResult.failure(_messageFor(e));
    }
  }

  String _messageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Tidak bisa terhubung ke server, cek koneksi.';
      default:
        break;
    }

    final data = e.response?.data;
    if (data is Map && data['errors'] is Map) {
      for (final value in (data['errors'] as Map).values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
      }
    }
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }

    return 'Gagal mengunggah foto.';
  }
}
