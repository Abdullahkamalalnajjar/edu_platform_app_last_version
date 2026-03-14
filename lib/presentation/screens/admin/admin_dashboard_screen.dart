import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/data/services/admin_service.dart';
import 'package:edu_platform_app/data/services/auth_service.dart';
import 'package:edu_platform_app/data/models/admin_statistics_model.dart';
import '../auth/login_screen.dart';
import 'all_students_screen.dart';
import 'all_teachers_screen.dart';
import 'all_parents_screen.dart';
import 'admin_subjects_screen.dart';
import 'admin_app_settings_screen.dart';
import '../../../data/services/settings_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _tokenService = TokenService();
  final _adminService = AdminService();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _selectedTab = 0;
  late AnimationController _animationController;
  AdminStatisticsModel? _statistics;
  bool _deleteAccountEnabled = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _loadStatistics();
    _checkDeleteAccountEnabled();
  }

  Future<void> _checkDeleteAccountEnabled() async {
    final settingsService = SettingsService();
    final response = await settingsService.getDeleteAccountEnabled();
    if (mounted && response.succeeded) {
      setState(() {
        _deleteAccountEnabled = response.data ?? false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final statistics = await _adminService.getStatistics();
      if (mounted) {
        setState(() {
          _statistics = statistics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _performLogout() async {
    // Get userId before clearing tokens
    final userId = await _tokenService.getUserGuid();

    // Call logout API to end session on server
    if (userId != null && userId.isNotEmpty) {
      final authService = AuthService();
      final response = await authService.logoutAllDevices(userId);
      print('--- Logout API Response ---');
      print('Succeeded: ${response.succeeded}');
      print('Message: ${response.message}');
      print('---------------------------');
    }

    // Clear local tokens
    await _tokenService.clearTokens();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'حذف الحساب',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد حذف الحساب؟',
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'حذف الحساب',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الحساب', textAlign: TextAlign.center),
            backgroundColor: AppColors.error,
          ),
        );
      }
      await _performLogout();
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد أنك تريد تسجيل الخروج؟',
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'تسجيل الخروج',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                _buildAppBar(),

                // Tab Navigation
                _buildTabNavigation(),

                // Content
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            // Top Right Orb
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.meshGold.withOpacity(0.15),
                      AppColors.meshGold.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Left Orb
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.meshNavy.withOpacity(0.2),
                      AppColors.meshNavy.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppBar() {
    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).cardColor
              : Theme.of(context).cardColor.withOpacity(0.8),
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Logo Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo_icon.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'لوحة التحكم',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'مدير النظام',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                children: [
                  _buildIconButton(
                    icon: Icons.refresh_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                    onTap: _loadStatistics,
                    tooltip: 'تحديث البيانات',
                  ),
                  const SizedBox(width: 12),
                  if (_deleteAccountEnabled)
                    _buildIconButton(
                      icon: Icons.delete_forever_rounded,
                      color: AppColors.error,
                      onTap: _handleDeleteAccount,
                      tooltip: 'حذف الحساب',
                      isDanger: true,
                    ),
                  if (_deleteAccountEnabled) const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.power_settings_new_rounded,
                    color: AppColors.error,
                    onTap: _handleLogout,
                    tooltip: 'تسجيل الخروج',
                    isDanger: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDanger
              ? color.withOpacity(0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDanger
                ? Colors.transparent
                : Theme.of(context).dividerColor,
          ),
          boxShadow: isDanger
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildTabNavigation() {
    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildTabButton('الإحصائيات', Icons.ssid_chart_rounded, 0),
            _buildTabButton('المستخدمين', Icons.people_alt_rounded, 1),
            _buildTabButton('النظام', Icons.settings_suggest_rounded, 2),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل البيانات',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStatistics,
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
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'إعادة المحاولة',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    switch (_selectedTab) {
      case 0:
        return _buildStatisticsTab();
      case 1:
        return _buildUsersTab();
      case 2:
        return _buildSystemTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatisticsTab() {
    return FadeIn(
      duration: const Duration(milliseconds: 400),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive Grid Logic
          int crossAxisCount = 2;
          double aspectRatio = 1.15;

          if (constraints.maxWidth > 1200) {
            crossAxisCount = 4;
            aspectRatio = 1.3;
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 3;
            aspectRatio = 1.2;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 2; // Tablet portrait / Large phone
            aspectRatio = 1.1;
          } else {
            // Mobile
            crossAxisCount = 2;
            aspectRatio =
                0.70; // Even more height for mobile to fix 7.4px overflow
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Header
                Text(
                  'نظرة عامة على الإحصائيات',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.headlineSmall?.color,
                  ),
                ),
                const SizedBox(height: 16),

                // Statistics Grid
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                  children: [
                    _buildStatCard(
                      'إجمالي المستخدمين',
                      '${_statistics?.totalRegisteredUsers ?? 0}',
                      Icons.people_rounded,
                      Theme.of(context).primaryColor,
                      _statistics?.registeredUsersChangeMessage ?? '',
                    ),
                    _buildStatCard(
                      'المعلمين',
                      '${_statistics?.totalTeachers ?? 0}',
                      Icons.school_rounded,
                      AppColors.secondary,
                      _statistics?.teachersChangeMessage ?? '',
                    ),
                    _buildStatCard(
                      'الطلاب',
                      '${_statistics?.totalStudents ?? 0}',
                      Icons.person_rounded,
                      AppColors.info,
                      _statistics?.studentsChangeMessage ?? '',
                    ),
                    _buildStatCard(
                      'أولياء الأمور',
                      '${_statistics?.totalParents ?? 0}',
                      Icons.family_restroom_rounded,
                      AppColors.success,
                      _statistics?.parentsChangeMessage ?? '',
                    ),
                    _buildStatCard(
                      'الدورات',
                      '${_statistics?.totalCourses ?? 0}',
                      Icons.class_rounded,
                      AppColors.warning,
                      _statistics?.coursesChangeMessage ?? '',
                    ),
                    _buildStatCard(
                      'الاختبارات',
                      '${_statistics?.totalExams ?? 0}',
                      Icons.assignment_rounded,
                      AppColors.meshBlue,
                      _statistics?.examsChangeMessage ?? '',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              // Optional: Add a small trend indicator or menu dots here
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up_rounded, size: 14, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return FadeIn(
      duration: const Duration(milliseconds: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إدارة المستخدمين',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // User Management Cards
            _buildUserManagementCard(
              'المعلمين',
              '${_statistics?.totalTeachers ?? 0}',
              Icons.school_rounded,
              AppColors.secondary,
              '',
            ),
            const SizedBox(height: 12),
            _buildUserManagementCard(
              'الطلاب',
              '${_statistics?.totalStudents ?? 0}',
              Icons.person_rounded,
              AppColors.info,
              '',
            ),
            const SizedBox(height: 12),
            _buildUserManagementCard(
              'أولياء الأمور',
              '${_statistics?.totalParents ?? 0}',
              Icons.family_restroom_rounded,
              AppColors.success,
              '',
            ),
            // const SizedBox(height: 24),

            // // Quick Actions
            // Text(
            //   'إجراءات سريعة',
            //   style: GoogleFonts.tajawal(
            //     fontSize: 18,
            //     fontWeight: FontWeight.bold,
            //     color: Theme.of(context).textTheme.headlineSmall?.color,
            //   ),
            // ),
            // const SizedBox(height: 12),
            // Row(
            //   children: [
            //     Expanded(
            //       child: _buildQuickActionButton(
            //         'إضافة معلم',
            //         Icons.person_add_rounded,
            //         AppColors.primary,
            //       ),
            //     ),
            //     const SizedBox(width: 12),
            //     Expanded(
            //       child: _buildQuickActionButton(
            //         'إضافة طالب',
            //         Icons.group_add_rounded,
            //         AppColors.secondary,
            //       ),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(
    String title,
    String count,
    IconData icon,
    Color color,
    String action,
  ) {
    return InkWell(
      onTap: () {
        if (title == 'الطلاب') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AllStudentsScreen()),
          );
        } else if (title == 'المعلمين') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AllTeachersScreen()),
          );
        } else if (title == 'أولياء الأمور') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AllParentsScreen()),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count.isEmpty || count == '0'
                        ? 'لا يوجد مستخدمين'
                        : '$count مستخدم',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemTab() {
    return FadeIn(
      duration: const Duration(milliseconds: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إعدادات النظام',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // System Settings
            _buildSystemSettingCard(
              'إدارة المواد',
              'تنظيم المواد الدراسية',
              Icons.book_rounded,
              AppColors.info,
            ),
            const SizedBox(height: 12),
            _buildSystemSettingCard(
              'إعدادات التطبيق',
              'إدارة بيانات التطبيق (من نحن، فيديو الشرح)',
              Icons.settings_applications_rounded,
              Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSettingCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        if (title == 'إدارة المواد') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminSubjectsScreen(),
            ),
          );
        } else if (title == 'إعدادات التطبيق') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminAppSettingsScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title - قريباً'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
