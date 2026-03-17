import 'dart:io';
import 'dart:math';
import 'dart:ui';
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
    with TickerProviderStateMixin {
  final _tokenService = TokenService();
  final _studentService = StudentService();
  final _userService = UserService();

  late AnimationController _compassController;
  late AnimationController _pulseController;
  late AnimationController _orbController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;

  final Random _random = Random();
  bool _hasInternetError = false;
  bool _isChecking = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    // Compass rotation
    _compassController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Pulse glow effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Background orb animation
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Shimmer effect
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

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
    _pulseController.dispose();
    _orbController.dispose();
    _shimmerController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background with animated gradient ──
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, _) {
              final t = _orbController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [
                            Color(0xFF050005),
                            Color(0xFF0A0000),
                            Color(0xFF150505),
                            Color(0xFF0A0000),
                          ],
                          stops: [
                            0.0,
                            0.3 + 0.05 * sin(t * 2 * pi),
                            0.6 + 0.05 * cos(t * 2 * pi),
                            1.0,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Color(0xFFFFF8F6),
                            Color(0xFFFFF0ED),
                            Color(0xFFFFF5F2),
                            Colors.white,
                          ],
                          stops: [
                            0.0,
                            0.35 + 0.05 * sin(t * 2 * pi),
                            0.7,
                            1.0,
                          ],
                        ),
                ),
              );
            },
          ),

          // ── Floating orbs ──
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, _) {
              final t = _orbController.value * 2 * pi;
              return Stack(
                children: [
                  // Top-right orb
                  Positioned(
                    top: -60 + 20 * sin(t),
                    right: -40 + 15 * cos(t),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(isDark ? 0.20 : 0.10),
                            AppColors.primary.withOpacity(isDark ? 0.05 : 0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom-left orb
                  Positioned(
                    bottom: -80 + 25 * cos(t * 0.7),
                    left: -60 + 20 * sin(t * 0.7),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.secondary.withOpacity(isDark ? 0.15 : 0.08),
                            AppColors.secondary.withOpacity(isDark ? 0.03 : 0.01),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Center-left accent orb
                  Positioned(
                    top: screenSize.height * 0.35 + 30 * sin(t * 1.2),
                    left: -100 + 20 * cos(t * 1.2),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF1744).withOpacity(isDark ? 0.10 : 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Subtle grid pattern overlay ──
          if (isDark)
            Opacity(
              opacity: 0.03,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/logo_icon.png'),
                    repeat: ImageRepeat.repeat,
                    scale: 8,
                  ),
                ),
              ),
            ),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // ── Logo with glow effect ──
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(
                                  _pulseAnimation.value * (isDark ? 0.35 : 0.2),
                                ),
                                blurRadius: 60 + (20 * _pulseAnimation.value),
                                spreadRadius: 5 * _pulseAnimation.value,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring
                          FadeIn(
                            duration: const Duration(milliseconds: 800),
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) {
                                return Container(
                                  width: 200 + (8 * _pulseAnimation.value),
                                  height: 200 + (8 * _pulseAnimation.value),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(
                                        0.15 + (0.1 * _pulseAnimation.value),
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Inner glass circle
                          FadeIn(
                            duration: const Duration(milliseconds: 600),
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.white.withOpacity(0.7),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : AppColors.primary.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: const SizedBox(),
                                ),
                              ),
                            ),
                          ),

                          // Rotating compass logo
                          AnimatedBuilder(
                            animation: _compassController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _compassController.value * 2 * pi,
                                child: child,
                              );
                            },
                            child: SizedBox(
                              width: 160,
                              height: 160,
                              child: Image.asset(
                                'assets/images/logo_icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── App name with shimmer ──
                    FadeInUp(
                      duration: const Duration(milliseconds: 1000),
                      delay: const Duration(milliseconds: 300),
                      from: 30,
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: isDark
                                ? [
                                    Colors.white,
                                    AppColors.primary,
                                    Colors.white,
                                  ]
                                : [
                                    AppColors.primaryDark,
                                    AppColors.primary,
                                    AppColors.primaryDark,
                                  ],
                            stops: const [0.0, 0.5, 1.0],
                          ).createShader(bounds);
                        },
                        child: Text(
                          'بوصلة',
                          style: GoogleFonts.tajawal(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Tagline ──
                    FadeInUp(
                      duration: const Duration(milliseconds: 1000),
                      delay: const Duration(milliseconds: 600),
                      from: 20,
                      child: Text(
                        'وجهتك نحو التميّز',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withOpacity(0.5)
                              : AppColors.textSecondaryLight,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),

                    // ── Loading / Error state ──
                    if (_hasInternetError)
                      _buildErrorCard(isDark)
                    else if (_isChecking)
                      _buildLoadingIndicator(isDark)
                    else
                      _buildLoadingIndicator(isDark),

                    const SizedBox(height: 40),

                    // ── Thinking student illustration ──
                    FadeInUp(
                      delay: const Duration(milliseconds: 800),
                      duration: const Duration(milliseconds: 1000),
                      from: 30,
                      child: Opacity(
                        opacity: isDark ? 0.6 : 0.8,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            'assets/images/thinking_student.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return FadeIn(
      delay: const Duration(milliseconds: 1200),
      duration: const Duration(milliseconds: 800),
      child: Column(
        children: [
          // Custom animated loading bar
          Container(
            width: 160,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : AppColors.primary.withOpacity(0.08),
            ),
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                return FractionallySizedBox(
                  alignment: Alignment(
                    -1.0 + 2.0 * _shimmerController.value,
                    0,
                  ),
                  widthFactor: 0.4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.primary.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'جاري التحميل...',
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withOpacity(0.35)
                  : AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? AppColors.error.withOpacity(0.15)
                : AppColors.error.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : AppColors.error.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              children: [
                // Error icon with animated pulse
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.error.withOpacity(
                              0.1 + 0.05 * _pulseAnimation.value,
                            ),
                            AppColors.error.withOpacity(0.03),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        size: 40,
                        color: AppColors.error.withOpacity(
                          0.7 + 0.3 * _pulseAnimation.value,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'لا يوجد اتصال بالإنترنت',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'تأكد من اتصالك بالشبكة ثم حاول مرة أخرى',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 28),
                // Retry button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkAuthAndNavigate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isChecking)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.refresh_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          _isChecking ? 'جاري الفحص...' : 'إعادة المحاولة',
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
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
