import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/data/services/fcm_service.dart';
import '../auth/login_screen.dart';
import 'main_screen.dart';
import '../teacher/teacher_dashboard_screen.dart';
import '../parent/parent_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import 'package:edu_platform_app/data/services/student_service.dart';
import 'package:edu_platform_app/data/services/user_service.dart';
import '../auth/complete_profile_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _tokenService = TokenService();
  final _studentService = StudentService();
  final _userService = UserService();
  late AnimationController _compassController;
  final Random _random = Random();
  bool _hasInternetError = false;
  bool _isChecking = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    _compassController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _startRandomRotation();
    _checkAuthAndNavigate();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        if (_hasInternetError && !_isChecking) {
          _checkAuthAndNavigate();
        }
      }
    });
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('apple.com')
            .timeout(const Duration(seconds: 4));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _startRandomRotation() {
    if (!mounted) return;

    final duration = Duration(milliseconds: 800 + _random.nextInt(1700));
    final randomRotation = (_random.nextDouble() - 0.5) * 3 * pi;
    final double target =
        _compassController.value + (randomRotation / (2 * pi));

    _compassController
        .animateTo(target, duration: duration, curve: Curves.easeInOutCubic)
        .then((_) {
      if (mounted) _startRandomRotation();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _compassController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    setState(() {
      _hasInternetError = false;
      _isChecking = true;
    });

    try {
      final hasInternet = await _hasInternetConnection();

      if (!hasInternet) {
        if (mounted) {
          setState(() {
            _hasInternetError = true;
            _isChecking = false;
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasInternetError = true;
          _isChecking = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isChecking = false;
    });

    final minSplashDuration = Future.delayed(const Duration(seconds: 5));
    final authCheckFuture = _performAuthCheck();

    final results = await Future.wait([minSplashDuration, authCheckFuture]);
    final Widget nextScreen = results[1] as Widget;

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<Widget> _performAuthCheck() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) return const LoginScreen();

      final role = await _tokenService.getRole();
      if (role == null || role.isEmpty) return const LoginScreen();

      final userGuid = await _tokenService.getUserGuid();
      if (userGuid != null) {
        try {
          final userProfile = await _userService.getProfile();
          if (!userProfile.succeeded) {
            await _tokenService.clearTokens();
            return const LoginScreen();
          }
        } catch (_) {}
      }

      FcmService.refreshAndUpdateToken();

      switch (role) {
        case 'Teacher':
        case 'Assistant':
          final teacherId = await _tokenService.getTeacherId();
          if (teacherId == null) return const LoginScreen();
          return const TeacherDashboardScreen();

        case 'Student':
          final userId = await _tokenService.getUserId();
          if (userId == null) return const LoginScreen();

          final isLocallyCompleted =
              await _tokenService.hasProfileCompleted(userId);
          if (isLocallyCompleted) return const MainScreen();

          try {
            final response = await _studentService.getProfile();
            if (response.succeeded && response.data != null) {
              final data = response.data!;
              final hasPhone = data['studentPhoneNumber'] != null &&
                  (data['studentPhoneNumber'] as String).isNotEmpty;
              final hasGov = data['governorate'] != null &&
                  (data['governorate'] as String).isNotEmpty;

              if (hasPhone && hasGov) {
                await _tokenService.setProfileCompleted(userId);
                return const MainScreen();
              }
            }
            return const CompleteProfileScreen();
          } catch (_) {
            return const MainScreen();
          }

        case 'Parent':
          return const ParentDashboardScreen();
        case 'Admin':
          return const AdminDashboardScreen();
        default:
          return const LoginScreen();
      }
    } catch (e) {
      debugPrint('Error during auth check: $e');
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _compassController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _compassController.value * 2 * pi,
                          child: child,
                        );
                      },
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: Image.asset(
                          'assets/images/logo_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -50,
                      child: FadeInLeft(
                        delay: const Duration(milliseconds: 500),
                        duration: const Duration(milliseconds: 1000),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Image.asset(
                            'assets/images/thinking_student.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FadeInUp(
                  duration: const Duration(milliseconds: 1200),
                  from: 30,
                  child: Text(
                    'بوصلة',
                    style: GoogleFonts.tajawal(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                if (_hasInternetError)
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.signal_wifi_connected_no_internet_4_rounded,
                              size: 48,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'عذراً، يوجد مشكلة في الإنترنت',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا يمكننا الاتصال بالخادم حالياً. يرجى التأكد من اتصالك بالشبكة ثم المحاولة مرة أخرى.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              height: 1.6,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isChecking ? null : _checkAuthAndNavigate,
                              icon: _isChecking
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                              label: Text(
                                _isChecking ? 'جاري الفحص...' : 'إعادة المحاولة',
                                style: GoogleFonts.tajawal(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isChecking)
                  Column(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'جاري التحقق من الاتصال...',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 48),
                const SizedBox(height: 20),
                FadeIn(
                  delay: const Duration(milliseconds: 1000),
                  child: SizedBox(
                    width: 25,
                    height: 25,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
