import 'dart:io';

/// Real account passwords for the backend integration test suite, read from
/// environment variables so they never live in source control. Every getter
/// here corresponds to a real employee record in the shared MySQL database
/// these tests run against — see each test file's own comments for why that
/// particular employee_code is used.
///
/// Run with e.g.:
///   QA_ADMIN_PASSWORD=xxx QA_FARHAN_PASSWORD=xxx QA_GOFAR_PASSWORD=xxx \
///   QA_ANDI_PASSWORD=xxx flutter test test/some_backend_integration_test.dart
class TestCredentials {
  static String _require(String key) {
    final value = Platform.environment[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env var $key for the backend integration tests. '
        'Set it before running `flutter test`, e.g.:\n'
        '  $key=xxx flutter test test/some_backend_integration_test.dart\n'
        'These are real account passwords and are intentionally never '
        'committed to source — ask whoever manages the QA database for the '
        'current values.',
      );
    }
    return value;
  }

  /// BBM-0001 — Super Admin.
  static String get adminPassword => _require('QA_ADMIN_PASSWORD');

  /// BBM-005 — Farhan (IT). The password he's currently sitting at; also
  /// the value login_backend_integration_test.dart sets him back to via
  /// submitNewPassword after each password-reset run, so every file that
  /// logs in as Farhan directly must agree on this same value.
  static String get farhanPassword => _require('QA_FARHAN_PASSWORD');

  /// BBM-006 — Gofar (IT). Has never been through the mandatory
  /// change-password flow, so this is his permanent password, not a
  /// temporary one.
  static String get gofarPassword => _require('QA_GOFAR_PASSWORD');

  /// BBM-0002 — Andi Pratama (Marketing). The value
  /// leaderboard_backend_integration_test.dart sets him to via
  /// submitNewPassword after resetting him through the admin API.
  static String get andiPassword => _require('QA_ANDI_PASSWORD');
}
