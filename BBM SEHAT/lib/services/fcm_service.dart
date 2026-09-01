import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'device_token_service.dart';

/// Entrypoint Firebase Messaging jalankan di isolate terpisah saat app di
/// background/terminated — harus top-level (bukan method) dan diberi
/// `vm:entry-point` supaya tidak ikut terbuang oleh tree-shaking di build
/// release.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// Wrapper FirebaseMessaging: minta izin notifikasi, ambil token, kirim
/// token ke backend (lihat DeviceTokenService), dan listener
/// foreground/tap/refresh.
///
/// Dipanggil setelah login berhasil (lihat AppState), bukan dari main() —
/// endpoint registrasi token butuh sesi Sanctum yang baru ada setelah
/// login. Singleton + flag [_listenersRegistered] supaya logout lalu login
/// lagi dalam satu proses app yang sama tidak mendaftarkan listener
/// FirebaseMessaging dua kali (yang berarti notifikasi foreground akan
/// tampil dobel). Registrasi token ke backend sengaja TIDAK ikut di-guard
/// oleh flag yang sama — initialize() dipanggil ulang tiap kali seseorang
/// login, dan device yang sama bisa dipakai gantian oleh karyawan berbeda
/// (mis. device testing), jadi token harus selalu dikirim ulang supaya
/// baris di device_tokens terhubung ke karyawan yang sedang login, bukan
/// nyangkut ke karyawan pertama yang login di proses app ini.
///
/// Saat app di foreground, Android tidak pernah menampilkan notifikasi FCM
/// secara otomatis (ini perilaku standar sistem, bukan bug) — jadi
/// [_androidChannel] di bawah dipakai untuk menampilkannya sendiri lewat
/// flutter_local_notifications. Kondisi background/terminated tidak
/// disentuh sama sekali karena sistem Android sudah menanganinya sendiri
/// lewat [firebaseMessagingBackgroundHandler].
class FCMService {
  FCMService._internal();
  static final FCMService instance = FCMService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final DeviceTokenService _deviceTokens = DeviceTokenService.instance;

  static const _androidChannel = AndroidNotificationChannel(
    'bbm_sehat_channel',
    'BBM Sehat',
    description: 'Notifikasi dari BBM Sehat',
    importance: Importance.high,
  );

  bool _listenersRegistered = false;

  // Fired whenever a notification is tapped, in any of the 3 states
  // (foreground via the local notification below, background via
  // onMessageOpenedApp, terminated via getInitialMessage) — always with
  // just the backend's custom 'type' data field (or null), never the raw
  // RemoteMessage, so this service stays UI-agnostic and AppState owns
  // the actual navigation decision.
  void Function(String? notificationType)? _onNotificationTap;

  Future<void> initialize({required void Function(String? notificationType) onNotificationTap}) async {
    _onNotificationTap = onNotificationTap;

    // FirebaseMessaging.instance throws if Firebase.initializeApp() (see
    // main()) never completed — a bad config, missing/outdated Google Play
    // Services on the device, or no network on first launch. This is the
    // one call site guaranteed to run that access first, so it's the right
    // place to fail soft: push notifications become unavailable for this
    // session, but every other screen/feature stays unaffected.
    final FirebaseMessaging messaging;
    try {
      messaging = FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('FCMService: Firebase tidak tersedia, notifikasi push dinonaktifkan — $e');
      return;
    }

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // Foreground taps never reach FirebaseMessaging.onMessageOpenedApp —
      // that only fires for a notification the *system* posted (Android
      // does that itself while backgrounded/terminated). The one shown
      // while foregrounded is ours, via flutter_local_notifications below,
      // so its own tap callback is the only place that foreground case is
      // reachable from.
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped (foreground): payload=${response.payload}');
        _onNotificationTap?.call(response.payload);
      },
    );

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission status: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    if (kDebugMode) debugPrint('FCM token: $token');
    if (token != null) await _registerToken(token);

    if (_listenersRegistered) return;
    _listenersRegistered = true;

    // Answers "what notification, if any, launched this app instance from
    // terminated" — only meaningful once per process, so it's checked here
    // alongside the listeners below rather than on every initialize() call.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from terminated by notification: ${initialMessage.data}');
      _onNotificationTap?.call(initialMessage.data['type'] as String?);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'FCM foreground message: ${message.notification?.title} - ${message.notification?.body}',
      );
      _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM notification tapped (background): ${message.notification?.title}');
      _onNotificationTap?.call(message.data['type'] as String?);
    });

    messaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) debugPrint('FCM token refreshed: $newToken');
      _registerToken(newToken);
    });
  }

  /// Wrapped separately from DeviceTokenService's own internal DioException
  /// handling — this is the outer safety net so any *other* unexpected
  /// failure here still can't take down the app or the caller.
  Future<void> _registerToken(String token) async {
    try {
      await _deviceTokens.register(token);
    } catch (e) {
      debugPrint('FCMService: gagal mendaftarkan token FCM ke backend — $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      // Carries the backend's 'type' data field through to the foreground
      // tap callback above — the only way that callback can know what kind
      // of notification this was, since it never sees the original
      // RemoteMessage.
      payload: message.data['type'] as String?,
    );
  }
}
