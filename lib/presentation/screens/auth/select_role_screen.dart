import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/auth_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/presentation/widgets/primary_button.dart';
import 'package:edu_platform_app/presentation/screens/teacher/complete_teacher_profile_screen.dart';
import 'package:edu_platform_app/presentation/screens/auth/complete_profile_screen.dart';
import 'package:edu_platform_app/data/services/notification_service.dart';

class SelectRoleScreen extends StatefulWidget {
  final String userId; // GUID
  final int? userIdInt;
  final int? teacherId;

  const SelectRoleScreen({
    super.key,
    required this.userId,
    this.userIdInt,
    this.teacherId,
  });

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen> {
  final _authService = AuthService();
  final _tokenService = TokenService();
  bool _isLoading = false;
  String? _selectedRole;

  Future<void> _submitRole() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار نوع الحساب')));
      return;
    }

    setState(() => _isLoading = true);

    final response = await _authService.updateUserRole(
      userId: widget.userId,
      newRole: _selectedRole!,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (response.succeeded) {
      // Save role locally
      await _tokenService.saveRole(_selectedRole!);

      // Subscribe to notification topics for this role
      await NotificationService.subscribeToTopicBasedOnRole(_selectedRole!);

      // Refresh token to get new claims (role)
      final refreshResult = await _authService.refreshToken();
      if (!refreshResult.succeeded) {
        // If refresh fails, maybe show warning but still try to proceed or just log it?
        // For now, let's log and show toast but proceed (or stop if critical).
        // Critical: Permissions depend on it.
        // Retry logic or force re-login might be needed ideally.
        print('Token Refresh Failed: ${refreshResult.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Warning: Session update failed. Please re-login if issues persist.',
            ),
          ),
        );
      }

      if (_selectedRole == 'Teacher') {
        // Since we just set the role, the profile is likely incomplete.
        // We navigate to CompleteTeacherProfileScreen.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompleteTeacherProfileScreen(
              userId: widget.userIdInt,
              teacherId: widget.teacherId,
            ),
          ),
        );
      } else {
        // Student
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompleteProfileScreen(
              isFirstLogin: true,
              userId: widget.userIdInt,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo_icon.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'اختيار نوع الحساب',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'الرجاء تحديد نوع حسابك للمتابعة',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              _buildRoleCard(
                title: 'طالب',
                icon: Icons.school_rounded,
                value: 'Student',
                description: 'تصفح الدورات والمحاضرات',
              ),

              const SizedBox(height: 16),

              _buildRoleCard(
                title: 'معلم',
                icon: Icons.person_pin_circle_rounded,
                value: 'Teacher',
                description: 'إنشاء وإدارة الدورات',
              ),

              const SizedBox(height: 48),

              PrimaryButton(
                onPressed: _submitRole,
                text: 'تأكيد ومتابعة',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required String value,
    required String description,
  }) {
    final isSelected = _selectedRole == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.inputBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
