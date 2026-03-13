import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();

    // Animation controller for the custom rotation
    _compassController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Default duration
    );

    _startRandomRotation();
    _checkAuthAndNavigate();
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  // Logic for random speed and direction rotation
  void _startRandomRotation() {
    if (!mounted) return;

    // Random duration between 800ms and 2500ms for each "move"
    final duration = Duration(milliseconds: 800 + _random.nextInt(1700));

    // Random target angle: current + (random between -1.5 and 1.5 full turns)
    // This allows it to flip direction and change speed naturally
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
    _compassController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    setState(() {
      _hasInternetError = false;
    });

    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternetError = true;
        });
      }
      return;
    }

    // Increased duration to 5 seconds as requested
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

      // If no token, strict login
      if (token == null) {
        return const LoginScreen();
      }

      final role = await _tokenService.getRole();

      // If no role selected/saved, strict login
      if (role == null || role.isEmpty) {
        return const LoginScreen();
      }

      // Check generic user profile existence using the provided endpoint
      // likely to validate if the user is still valid in the system
      final userGuid = await _tokenService.getUserGuid();
      if (userGuid != null) {
        try {
          final userProfile = await _userService.getProfile();
          if (!userProfile.succeeded) {
            // If we can't get the basic user profile, something is wrong (deleted user?)
            // Force login
            await _tokenService.clearTokens();
            return const LoginScreen();
          }
        } catch (_) {
          // Network error or other issue?
          // If strict, return LoginScreen. If lenient for offline, continue.
          // Given "no return login", we lean towards strict but let's see.
          // For now, if active validation fails, we might want to trust local token
          // UNLESS it's a 404/401 which UserService handles.
        }
      }

      FcmService.refreshAndUpdateToken();

      switch (role) {
        case 'Teacher':
        case 'Assistant':
          final teacherId = await _tokenService.getTeacherId();
          // If Teacher has no ID, strict login
          if (teacherId == null) {
            return const LoginScreen();
          }
          return const TeacherDashboardScreen();

        case 'Student':
          final userId = await _tokenService.getUserId();
          // If Student has no ID, strict login
          if (userId == null) {
            return const LoginScreen();
          }

          // Check if profile is complete
          final isLocallyCompleted = await _tokenService.hasProfileCompleted(
            userId,
          );

          if (isLocallyCompleted) {
            return const MainScreen();
          }

          // Verify with API if local flag is false
          try {
            final response = await _studentService.getProfile();
            if (response.succeeded && response.data != null) {
              final data = response.data!;
              final hasPhone =
                  data['studentPhoneNumber'] != null &&
                  (data['studentPhoneNumber'] as String).isNotEmpty;
              final hasGov =
                  data['governorate'] != null &&
                  (data['governorate'] as String).isNotEmpty;

              if (hasPhone && hasGov) {
                await _tokenService.setProfileCompleted(userId);
                return const MainScreen();
              }
            }
            return const CompleteProfileScreen();
          } catch (_) {
            // On error, if we have ID, let them in (or strictly login? User said "return to login if NO ID".
            // If ID exists but network fails, MainScreen is safer to avoid lockout,
            // but strict security might prefer Login. Keeping MainScreen for UX stability on network error).
            return const MainScreen();
          }

        case 'Parent':
          return const ParentDashboardScreen();
        case 'Admin':
          return const AdminDashboardScreen();
        default:
          // Unknown role? Strict login
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom Rotating Compass with Randomized Logic + Thinking Student
            Stack(
              clipBehavior: Clip.none,
              children: [
                // The Compass
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
                // Thinking Student Image (Back to being on top)
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
            const SizedBox(height: 30),

            // Native Text widget for perfect transparency and high quality
            FadeInUp(
              duration: const Duration(milliseconds: 1200),
              from: 30,
              child: Text(
                'بوصلة',
                style: GoogleFonts.cairo(
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Theme.of(context).primaryColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 60),

            if (_hasInternetError)
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: Column(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا يوجد اتصال بالإنترنت',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يرجى التحقق من اتصالك والمحاولة مرة أخرى',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _checkAuthAndNavigate,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        'إعادة المحاولة',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Minimalist Loading Indicator
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
    );
  }
}
