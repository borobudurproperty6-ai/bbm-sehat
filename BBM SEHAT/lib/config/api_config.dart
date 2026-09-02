class ApiConfig {
  ApiConfig._();

  /// Change this one line when switching how you're testing the app —
  /// nothing else in the codebase should hardcode a host.
  ///
  /// - `flutter run -d chrome` and `flutter test` (both this Mac's own web
  ///   engine/VM): 127.0.0.1 works as-is, the default below. Note:
  ///   `defaultTargetPlatform` can't be used to auto-detect Android here —
  ///   flutter_test deliberately always reports TargetPlatform.android
  ///   under tests (see the SDK's platform.dart docs), so an "auto" version
  ///   of this would silently break every backend-integration test.
  /// - Android Emulator: 127.0.0.1 inside the emulator refers to the
  ///   emulator itself, not this Mac — use `http://10.0.2.2:8000/api`.
  /// - Physical Android/iOS device on the same Wi-Fi: use this Mac's LAN IP
  ///   instead (`ipconfig getifaddr en0`), e.g. `http://192.168.1.23:8000/api`.
  ///
  /// TEMPORARY — smoke test with 2 physical phones on the office Wi-Fi
  /// (2026-08-28): pointed at this dev Mac's LAN IP instead of an emulator,
  /// since the app is being sideloaded onto real devices, not run in an
  /// emulator. Only works while this Mac stays on and on the same LAN as
  /// the test phones, running `php artisan serve --host=0.0.0.0`. MUST be
  /// changed again once the backend moves to a real deployed server (this
  /// LAN IP will be meaningless off this network / once the Mac is off) —
  /// don't ship this value in the eventual UAT/production build.
  static const String baseUrl = 'https://api.bbmsehat.id/api';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  /// The backend builds absolute file URLs (e.g. profile photos) from its
  /// own APP_URL, which is whatever host the *server* was configured with
  /// (typically `localhost`) — not necessarily the host this *client* uses
  /// to reach it (`10.0.2.2` on an Android emulator, a LAN IP on a physical
  /// device, etc). Swapping in [baseUrl]'s scheme/host/port keeps every
  /// asset URL reachable no matter which of the environments above this app
  /// is currently running under, without the backend needing to know or
  /// guess who's asking.
  static String resolveAssetUrl(String url) {
    final client = Uri.parse(baseUrl);
    final asset = Uri.tryParse(url);
    if (asset == null) return url;

    return asset.replace(scheme: client.scheme, host: client.host, port: client.port).toString();
  }
}
