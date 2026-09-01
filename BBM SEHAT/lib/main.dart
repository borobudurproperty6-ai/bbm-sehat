import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'screens/app_shell.dart';
import 'screens/change_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'state/activity_state.dart';
import 'state/app_state.dart';
import 'state/employee_detail_state.dart';
import 'state/employee_state.dart';
import 'state/history_state.dart';
import 'state/leaderboard_state.dart';
import 'state/monitoring_state.dart';
import 'state/points_state.dart';
import 'state/walk_session_state.dart';
import 'theme/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push notifications (FCM) are a nice-to-have layered on top of the app,
  // not something any core screen depends on — a phone with an outdated/
  // missing Google Play Services, a bad google-services.json, or no network
  // on first launch must never turn into the whole app failing to open.
  // FCMService.initialize() (called after login, see AppState) independently
  // fails soft too, for the same reason.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase gagal diinisialisasi — notifikasi push dinonaktifkan: $e');
  }

  await initializeDateFormatting('id_ID');
  runApp(const BbmSehatApp());
}

class BbmSehatApp extends StatelessWidget {
  const BbmSehatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => EmployeeState()),
        ChangeNotifierProvider(create: (_) => ActivityState()),
        ChangeNotifierProvider(create: (_) => PointsState()),
        ChangeNotifierProvider(create: (_) => LeaderboardState()),
        ChangeNotifierProvider(create: (_) => HistoryState()),
        ChangeNotifierProvider(create: (_) => WalkSessionState()),
        ChangeNotifierProvider(create: (_) => MonitoringState()),
        ChangeNotifierProvider(create: (_) => EmployeeDetailState()),
      ],
      child: MaterialApp(
        title: 'BBM Sehat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.accent,
            brightness: Brightness.dark,
            surface: AppColors.bg,
          ),
          textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.accent),
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppState>().flow;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: switch (flow) {
          AppFlow.splash => const SplashScreen(key: ValueKey('splash')),
          AppFlow.login => const LoginScreen(key: ValueKey('login')),
          AppFlow.changePassword => const ChangePasswordScreen(key: ValueKey('change-password')),
          AppFlow.app => const AppShell(key: ValueKey('app')),
        },
      ),
    );
  }
}
