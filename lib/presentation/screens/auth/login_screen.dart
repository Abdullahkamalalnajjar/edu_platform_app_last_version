import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/auth_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/data/services/assistant_service.dart';
import 'package:edu_platform_app/data/services/settings_service.dart';
import 'package:edu_platform_app/domain/usecases/auth/google_login_usecase.dart'; // Added UseCase
import 'package:edu_platform_app/presentation/widgets/custom_text_field.dart';
import 'package:edu_platform_app/presentation/widgets/primary_button.dart';
import 'signup_screen.dart';
import 'package:edu_platform_app/presentation/screens/shared/main_screen.dart';

import '../teacher/teacher_dashboard_screen.dart';
import '../parent/parent_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import 'forgot_password_screen.dart';
import 'complete_profile_screen.dart';
import '../teacher/complete_teacher_profile_screen.dart';
import 'select_role_screen.dart';
import '../admin/explanation_video_screen.dart';
import 'package:edu_platform_app/data/services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Support Number - Change this value to control the support WhatsApp number
  final String _supportPhoneNumber = '+201030201439';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _tokenService = TokenService();
  final _assistantService = AssistantService();
  final _settingsService = SettingsService();
  final _googleLoginUseCase =
      GoogleLoginUseCase(); // UseCase instead of Service

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isVideoLoading = false;
  bool _isGoogleLoginEnabled = false; // Track if Google login is enabled

  late AnimationController _backgroundController;
  late AnimationController _logoRotationController;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _logoRotationController = AnimationController(
      vsync: this,
      lowerBound: -1000000,
      upperBound: 1000000,
    );

    _startRandomLogoRotation();
    _checkGoogleLoginStatus();
  }

  Future<void> _checkGoogleLoginStatus() async {
    try {
      final response = await _settingsService.getGoogleLoginEnabled();
      if (mounted && response.succeeded && response.data != null) {
        setState(() {
          _isGoogleLoginEnabled = response.data!;
        });
      }
    } catch (e) {
      print('Error checking Google login status: $e');
      // Default to false on error
    }
  }

  void _startRandomLogoRotation() {
    if (!mounted) return;

    // Speed reference: 30 RPM = 2000ms per full 1.0 rotation
    const double msPerFullRotation = 2000;

    // Random rotation amount (between 0.2 and 0.6 of a full lap)
    // This ensures it changes direction before completing a single turn
    final rotationDelta = 0.2 + (math.Random().nextDouble() * 0.4);

    // Randomly choose direction
    final isClockwise = math.Random().nextBool();

    // Calculate new target value based on current position
    final currentVal = _logoRotationController.value;
    final targetVal = isClockwise
        ? currentVal + rotationDelta
        : currentVal - rotationDelta;

    // Calculate duration to maintain consistent speed
    final durationMs = (rotationDelta * msPerFullRotation).toInt();

    _logoRotationController
        .animateTo(
          targetVal,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeInOutQuad,
        )
        .then((_) => _startRandomLogoRotation());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _backgroundController.dispose();
    _logoRotationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final response = await _authService.login(
      _emailController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (response.succeeded && response.data != null) {
      // Check if user is disabled and is a Teacher
      if (response.data!.isDisable &&
          response.data!.roles.contains('Teacher')) {
        // Show pending approval message for disabled teachers
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.pending_outlined,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'في انتظار الموافقة',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عزيزي المعلم ${response.data!.firstName} ${response.data!.lastName}،',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'حسابك قيد المراجعة حالياً وفي انتظار موافقة الإدارة. سيتم تفعيل حسابك قريباً وسنقوم بإشعارك عند الموافقة.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'نشكرك على صبرك وتفهمك',
                          style: GoogleFonts.inter(
                            color: Theme.of(context).primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'حسناً',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
        return; // Stop login process
      }

      await _tokenService.saveToken(response.data!.token);
      await _tokenService.saveRefreshToken(response.data!.refreshToken);
      if (response.data!.userId != null) {
        await _tokenService.saveUserId(response.data!.userId!);
      }
      // Save GUID
      await _tokenService.saveUserGuid(
        response.data!.applicationUserId ?? response.data!.id,
      );

      // Save User Info
      await _tokenService.saveUserInfo(
        name: '${response.data!.firstName} ${response.data!.lastName}',
        email: response.data!.email,
      );

      await _tokenService.saveExtendedUserInfo(
        photoUrl: response.data!.photoUrl,
        phoneNumber: response.data!.phoneNumber,
        facebookUrl: response.data!.facebookUrl,
        telegramUrl: response.data!.telegramUrl,
        whatsAppNumber: response.data!.whatsAppNumber,
        youTubeChannelUrl: response.data!.youTubeChannelUrl,
      );

      if (response.data!.teacherId != null) {
        await _tokenService.saveTeacherId(response.data!.teacherId!);
      } else if (response.data!.roles.contains('Assistant')) {
        try {
          final assistantResp = await _assistantService.getAssistantByUserId(
            response.data!.id,
          );
          if (assistantResp.succeeded && assistantResp.data != null) {
            await _tokenService.saveTeacherId(assistantResp.data!.teacherId);
          }
        } catch (e) {
          print('Error fetching assistant details: $e');
        }
      }

      // Save Role
      final roles = response.data!.roles;
      if (roles.isNotEmpty) {
        // Prioritize specific roles if multiple exist, otherwise take the first one
        String roleToSave = roles.first;
        if (roles.contains('Admin'))
          roleToSave = 'Admin';
        else if (roles.contains('Teacher'))
          roleToSave = 'Teacher';
        else if (roles.contains('Assistant'))
          roleToSave = 'Assistant'; // Add Assistant priority
        else if (roles.contains('Student'))
          roleToSave = 'Student';
        else if (roles.contains('Parent'))
          roleToSave = 'Parent';
        await _tokenService.saveRole(roleToSave);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('مرحباً بك، ${response.data!.firstName}!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Navigate based on roles
      final savedRole = await _tokenService.getRole();
      if (savedRole != null) {
        await NotificationService.subscribeToTopicBasedOnRole(savedRole);
      }

      if (roles.contains('Admin')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else if (roles.contains('Teacher') || roles.contains('Assistant')) {
        if (roles.contains('Teacher')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TeacherDashboardScreen(),
            ),
          );
        } else {
          // Assistant
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TeacherDashboardScreen(),
            ),
          );
        }
      } else if (roles.contains('Student')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else if (roles.contains('Parent')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ParentDashboardScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else {
      // Check if it's a 400 error (account in use on another device)
      if (response.statusCode == 400) {
        final bool isDisabled = response.message.toLowerCase().contains(
          'disabled',
        );

        // Show simple dialog for device conflict or pending approval
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDisabled ? Colors.orange : AppColors.error)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDisabled
                        ? Icons.access_time_rounded
                        : Icons.devices_other_rounded,
                    color: isDisabled ? Colors.orange : AppColors.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isDisabled ? 'في انتظار الموافقة' : 'الحساب مستخدم',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              isDisabled
                  ? 'حسابك قيد المراجعة حالياً وفي انتظار موافقة المسؤول. سيتم تفعيل حسابك قريباً.'
                  : (response.message.isNotEmpty
                        ? response.message
                        : 'هذا الحساب مفتوح حالياً على جهاز آخر.\n\nيرجى تسجيل الخروج من الجهاز الآخر أولاً.'),
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'حسناً',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      } else {
        // Show regular error snackbar for other errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(response.message)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      final result = await _googleLoginUseCase.execute();

      setState(() => _isGoogleLoading = false);

      if (!mounted) return;

      if (result.success) {
        // Show Success Message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('مرحباً بك، ${result.userName}!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (result.role == null || result.roles.isEmpty) {
          // No role assigned, navigate to Select Role Screen
          if (result.userGuid != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SelectRoleScreen(
                  userId: result.userGuid!,
                  userIdInt: result.userId,
                  teacherId: result.teacherId,
                ),
              ),
            );
          } else {
            // Should not happen if successful, but fallback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: User ID missing')),
            );
          }
        } else if (result.role == 'Teacher' && result.isDisabled) {
          // Handle Disabled Teacher (Pending Approval) after Google Sign In
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'في انتظار الموافقة',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                'تم تسجيل الدخول بنجاح، ولكن حسابك في انتظار موافقة المسؤول.\nيرجى الانتظار حتى يتم تفعيل الحساب.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Stay on Login
                    Navigator.pop(context);
                  },
                  child: Text(
                    'حسناً',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Navigate based on role
          _navigateBasedOnRole(
            result.role!,
            userId: result.userId,
            isProfileComplete: result.isProfileComplete,
          );
        }
      } else {
        // Show Error Message
        if (result.message != null && result.message!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(result.message!)),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Google Login Error in UI: $e');
      setState(() => _isGoogleLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('حدث خطأ غير متوقع أثناء تسجيل الدخول'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _navigateBasedOnRole(
    String role, {
    int? userId,
    bool? isProfileComplete,
  }) async {
    // Subscribe to notification topics for this role
    await NotificationService.subscribeToTopicBasedOnRole(role);

    if (role == 'Admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    } else if (role == 'Teacher') {
      bool profileComplete = isProfileComplete ?? false;
      if (isProfileComplete == null && userId != null) {
        // Fallback: check locally or assume false
        // For now, we assume false to ensure data integrity
        profileComplete = false;
      }

      if (!profileComplete) {
        // We might need teacherId here. For Google Login, we don't readily have it in `userId` arg only.
        // But `GoogleLoginUseCase` returns `userId` (int). It doesn't return `teacherId` in `GoogleLoginResult` explicitly.
        // However, `TokenService` has it saved.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompleteTeacherProfileScreen(userId: userId),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TeacherDashboardScreen(),
          ),
        );
      }
    } else if (role == 'Assistant') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TeacherDashboardScreen()),
      );
    } else if (role == 'Student') {
      // Check if profile is complete
      bool profileComplete = isProfileComplete ?? false;

      // If not passed (should not happen with new logic), fallback to checking phone
      if (isProfileComplete == null) {
        if (userId != null) {
          profileComplete = await _tokenService.hasProfileCompleted(userId);
        } else {
          final phone = await _tokenService.getPhoneNumber();
          profileComplete = (phone != null && phone.isNotEmpty);
        }
      }

      if (!profileComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CompleteProfileScreen(isFirstLogin: true, userId: userId),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else if (role == 'Parent') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ParentDashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  Future<void> _viewExplanationVideo() async {
    setState(() => _isVideoLoading = true);
    try {
      final response = await _settingsService.getExplanationVideoUrl();

      if (!mounted) {
        return;
      }

      if (response.succeeded &&
          response.data != null &&
          response.data!.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ExplanationVideoScreen(videoUrl: response.data!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحميل الفيديو')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVideoLoading = false);
      }
    }
  }

  Future<void> _contactSupport() async {
    String phoneNumber = _supportPhoneNumber;

    // Try to fetch from API first
    try {
      final response = await _settingsService.getSupportPhoneNumber();
      if (response.succeeded &&
          response.data != null &&
          response.data!.isNotEmpty) {
        phoneNumber = response.data!;
      }
    } catch (e) {
      print('Error fetching support phone, using fallback: $e');
    }

    // Launch WhatsApp
    final uri = Uri.parse('https://wa.me/$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح واتساب الدعم')),
          );
        }
      }
    } catch (e) {
      print('Error launching support: $e');
    }
  }

  Future<void> _shareApp() async {
    String appUrl = 'https://bosla-education.com';

    // Try to fetch from API first
    try {
      final response = await _settingsService.getApplicationUrl();
      if (response.succeeded &&
          response.data != null &&
          response.data!.isNotEmpty) {
        appUrl = response.data!;
        // Add https:// if not present
        if (!appUrl.startsWith('http://') && !appUrl.startsWith('https://')) {
          appUrl = 'https://$appUrl';
        }
      }
    } catch (e) {
      print('Error fetching application URL, using fallback: $e');
    }

    // Open URL in browser
    final uri = Uri.parse(appUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
        }
      }
    } catch (e) {
      print('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء فتح الرابط')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Premium Dynamic Animated Background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1a0b2e),
                              const Color(0xFF3B0000),
                              const Color(0xFF121212),
                            ]
                          : [
                              AppColors.primary.withOpacity(0.05),
                              AppColors.primary.withOpacity(0.15),
                              Colors.white,
                            ],
                      stops: [
                        0.0,
                        0.5 + 0.2 * math.sin(_backgroundController.value * 2 * math.pi),
                        1.0
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Decorative Geometric Blur Orbs ──
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? Colors.orange : AppColors.primary)
                        .withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main Content ──
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: size.height * 0.04), // المسافة من الأعلى
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildLoginCard(isDark),
                      const SizedBox(height: 32),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInDown(
      duration: const Duration(milliseconds: 800),
      child: Column(
        children: [
          // Rotating Logo inside a glowing glass container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).cardColor.withOpacity(0.3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: RotationTransition(
              turns: _logoRotationController,
              child: Image.asset(
                'assets/images/logo_icon.png',
                width: 130,
                height: 130,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'أهلاً بك في منصة بوصلة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [
                    AppColors.primary,
                    Colors.redAccent,
                  ],
                ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(2.0, 2.0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'وجهتك الأولى نحو التفوق والتميز',
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(bool isDark) {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      delay: const Duration(milliseconds: 200),
      // Glassmorphic Card
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(isDark ? 0.6 : 0.8),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(isDark ? 0.1 : 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تسجيل الدخول',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Email Field
            CustomTextField(
              controller: _emailController,
              hintText: 'البريد الإلكتروني',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال البريد الإلكتروني';
                }
                if (!value.contains('@')) {
                  return 'الرجاء إدخال بريد إلكتروني صحيح';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Password Field
            CustomTextField(
              controller: _passwordController,
              hintText: 'كلمة المرور',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال كلمة المرور';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Forgot Password
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'نسيت كلمة المرور؟',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Sign In Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: PrimaryButton(
                      onPressed: _handleLogin,
                      text: 'تسجيل الدخول',
                      isLoading: _isLoading,
                      icon: Icons.arrow_forward_rounded,
                      height: 56,
                    ),
                  ),
                ),
                if (_isGoogleLoginEnabled) ...[
                  const SizedBox(width: 16),
                  _buildGoogleSignInButton(isDark),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(bool isDark) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isGoogleLoading || _isLoading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isGoogleLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : Image.network(
                    'https://img.icons8.com/color/48/000000/google-logo.png',
                    height: 26,
                    width: 26,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      delay: const Duration(milliseconds: 400),
      child: Column(
        children: [
          // Sign Up Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "ليس لديك حساب؟ ",
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'إنشاء حساب جديد',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Support and Share Buttons in a sophisticated container
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildFooterButton(
                  onTap: _contactSupport,
                  icon: FontAwesomeIcons.whatsapp,
                  label: 'المساعدة',
                  color: const Color(0xFF25D366),
                ),
                Container(width: 1, height: 20, color: Theme.of(context).dividerColor, margin: const EdgeInsets.only(top: 8)),
                _buildFooterButton(
                  onTap: _isVideoLoading ? () {} : _viewExplanationVideo,
                  icon: Icons.play_circle_outline_rounded,
                  label: 'الشرح',
                  color: AppColors.accent,
                  isLoading: _isVideoLoading,
                ),
                Container(width: 1, height: 20, color: Theme.of(context).dividerColor, margin: const EdgeInsets.only(top: 8)),
                _buildFooterButton(
                  onTap: _shareApp,
                  icon: Icons.share_rounded,
                  label: 'مشاركة',
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
