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
          // ── Rich Animated Background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                final t = _backgroundController.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: const [
                              Color(0xFF0A0000),
                              Color(0xFF1A0000),
                              Color(0xFF0A0000),
                            ],
                            stops: [
                              0.0,
                              0.5 + 0.15 * math.sin(t * 2 * math.pi),
                              1.0
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: const [
                              Colors.white,
                              Color(0xFFFFF5F5),
                              Colors.white,
                            ],
                            stops: [
                              0.0,
                              0.5 + 0.15 * math.sin(t * 2 * math.pi),
                              1.0
                            ],
                          ),
                  ),
                );
              },
            ),
          ),

          // ── Decorative Orbs ──
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(isDark ? 0.30 : 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(isDark ? 0.20 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Extra dark-mode red mid-orb
          if (isDark)
            Positioned(
              top: 300,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFB71C1C).withOpacity(0.18),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - 80),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 600 ? size.width * 0.15 : 24,
                    vertical: 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: size.height * 0.03),
                        _buildHeader(),
                        const SizedBox(height: 28),
                        _buildLoginCard(isDark),
                        const SizedBox(height: 20),
                        _buildFooter(),
                        const SizedBox(height: 16),
                      ],
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInDown(
      duration: const Duration(milliseconds: 700),
      child: Column(
        children: [
          // Premium logo with glow ring
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.white.withOpacity(0.85),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: RotationTransition(
                  turns: _logoRotationController,
                  child: Image.asset(
                    'assets/images/logo_icon.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, Color(0xFFE53935)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: Text(
              'منصة بوصلة',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'وجهتك الأولى نحو التفوق والتميز',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(bool isDark) {
    return FadeInUp(
      duration: const Duration(milliseconds: 700),
      delay: const Duration(milliseconds: 150),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A0000).withOpacity(0.75)
              : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withOpacity(0.25)
                : AppColors.primary.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
              blurRadius: 40,
              spreadRadius: -8,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
              blurRadius: 40,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card header with accent bar
            Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'تسجيل الدخول',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Email label + Field
            _buildInputLabel('البريد الإلكتروني'),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _emailController,
              hintText: 'example@email.com',
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

            // Password label + Field
            _buildInputLabel('كلمة المرور'),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _passwordController,
              hintText: '••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال كلمة المرور';
                }
                return null;
              },
            ),

            const SizedBox(height: 6),

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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

            const SizedBox(height: 20),

            // Sign In Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFE53935)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _handleLogin,
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'تسجيل الدخول',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isGoogleLoginEnabled) ...[
                  const SizedBox(width: 12),
                  _buildGoogleSignInButton(isDark),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
      ),
    );
  }

  Widget _buildGoogleSignInButton(bool isDark) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isGoogleLoading || _isLoading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: _isGoogleLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInUp(
      duration: const Duration(milliseconds: 700),
      delay: const Duration(milliseconds: 300),
      child: Column(
        children: [
          // Register row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ليس لديك حساب؟',
                style: GoogleFonts.inter(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                child: Text(
                  'إنشاء حساب',
                  style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Bottom action cards
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  onTap: _contactSupport,
                  icon: FontAwesomeIcons.whatsapp,
                  label: 'المساعدة',
                  color: const Color(0xFF25D366),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionCard(
                  onTap: _isVideoLoading ? () {} : _viewExplanationVideo,
                  icon: Icons.play_circle_rounded,
                  label: 'شرح التطبيق',
                  color: AppColors.primary,
                  isDark: isDark,
                  isLoading: _isVideoLoading,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionCard(
                  onTap: _shareApp,
                  icon: Icons.share_rounded,
                  label: 'مشاركة',
                  color: const Color(0xFF5C6BC0),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? color.withOpacity(0.15)
                : color.withOpacity(0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.08 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.15 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, size: 18, color: color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
