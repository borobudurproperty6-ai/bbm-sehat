import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin seam over the actual storage backend, so AuthService can be tested
/// against a real backend server without needing flutter_secure_storage's
/// native platform channel (which isn't available under `flutter test`).
abstract class TokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
