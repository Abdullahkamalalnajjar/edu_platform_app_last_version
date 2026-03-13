import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_theme.dart';
import 'core/network/api_client.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/teacher/teacher_dashboard_screen.dart';
import 'presentation/screens/shared/main_screen.dart';
import 'presentation/screens/parent/parent_dashboard_screen.dart';
import 'presentation/screens/admin/admin_dashboard_screen.dart';

import 'data/services/fcm_service.dart';
import 'data/services/notification_service.dart';
import 'presentation/screens/shared/splash_screen.dart';
import 'data/services/theme_service.dart'; // Import ThemeService
import 'data/services/settings_service.dart';
import 'core/constants/app_constants.dart';

// Helper function to check for configuration
Future<void> _checkForConfigUpdates() async {
  final settingsService = SettingsService();
  final response = await settingsService.getIconPricerEnabled();

  if (response.succeeded && response.data != null) {
    AppConstants.data = response.data!;
    print('Updated AppConstants.data to: ${AppConstants.data}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCr1zhbooCNAb5GezqlHYCn70cqbgBqJbY",
        appId: "1:938189024020:android:47f678322f9f64341cb001",
        messagingSenderId: "938189024020",

        projectId: "edu-platform-3ac0b",
      ),
    );

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize FCM after Firebase is ready
    await FcmService.initialize();

    // Initialize Notification handling (for tap navigation)
    await NotificationService.initialize();

    // Initialize Theme Service
    await ThemeService.initialize();
  } catch (e) {
    print('Warning: Firebase initialization failed: $e');
    // App can still run without Firebase for web or if not configured
  }

  // Check for configuration updates on startup
  try {
    _checkForConfigUpdates();
  } catch (e) {
    print('Warning: Config check failed: $e');
  }

  // Set system UI overlay style for premium dark theme (Initial default)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1E293B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const EduPlatformApp());
}

class EduPlatformApp extends StatelessWidget {
  const EduPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'منصة بوصلة - Bosla',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          navigatorKey: navigatorKey, // Global navigator key for API client
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Define named routes for navigation
          routes: {
            '/login': (context) => const LoginScreen(),
            '/main': (context) => const MainScreen(),
            '/teacher': (context) => const TeacherDashboardScreen(),
            '/parent': (context) => const ParentDashboardScreen(),
            '/admin': (context) => const AdminDashboardScreen(),
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
