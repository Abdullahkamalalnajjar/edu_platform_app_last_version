import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:edu_platform_app/data/services/theme_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final _tokenService = TokenService();
  final _adminService = AdminService();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _selectedIndex = 0;

  late AnimationController _bgAnimController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  AdminStatisticsModel? _statistics;
  bool _deleteAccountEnabled = false;
  String? _adminName;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  Future<void> _loadData() async {
    _adminName = await _tokenService.getUserName();
    await _loadStatistics();
    await _checkDeleteAccountEnabled();
  }

  Future<void> _checkDeleteAccountEnabled() async {
    final settingsService = SettingsService();
    final response = await settingsService.getDeleteAccountEnabled();
    if (mounted && response.succeeded) {
      setState(() => _deleteAccountEnabled = response.data ?? false);
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
    _bgAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _performLogout() async {
    final userId = await _tokenService.getUserGuid();
    if (userId != null && userId.isNotEmpty) {
      final authService = AuthService();
      await authService.logoutAllDevices(userId);
    }
    await _tokenService.clearTokens();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await _showConfirmDialog(
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      confirmText: 'خروج',
      icon: Icons.logout_rounded,
      isDanger: true,
    );
    if (confirmed == true) await _performLogout();
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await _showConfirmDialog(
      title: 'حذف الحساب',
      message: 'هل أنت متأكد من حذف الحساب؟ هذا الإجراء لا يمكن التراجع عنه.',
      confirmText: 'حذف',
      icon: Icons.delete_forever_rounded,
      isDanger: true,
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

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required IconData icon,
    bool isDanger = false,
  }) {
    final color = isDanger ? AppColors.error : AppColors.primary;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.inter(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              confirmText,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            _buildAnimatedBackground(isDark),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: _buildBody(),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(isDark),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ANIMATED BACKGROUND
  // ═══════════════════════════════════════════════════════
  Widget _buildAnimatedBackground(bool isDark) {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        final t = _bgAnimController.value;
        return Stack(
          children: [
            Positioned(
              top: -80 + (t * 30),
              right: -80 + (t * 20),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(isDark ? 0.18 : 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120 - (t * 20),
              left: -80 + (t * 15),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withOpacity(isDark ? 0.15 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: -60 - (t * 10),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.info.withOpacity(isDark ? 0.12 : 0.06),
                      Colors.transparent,
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

  // ═══════════════════════════════════════════════════════
  // HEADER — Premium Gradient AppBar
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader(bool isDark) {
    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: ClipPath(
        clipper: _WaveClipper(),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 52),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1035),
                      AppColors.primary.withOpacity(0.85),
                      const Color(0xFF0D1B4B),
                    ]
                  : [
                      AppColors.primary,
                      const Color(0xFF6C5CE7),
                      AppColors.primary.withOpacity(0.8),
                    ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Row ──────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Glowing avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ADMIN',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'مرحباً، ${_adminName ?? 'المدير'}',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'لوحة تحكم النظام',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.65),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeService.themeModeNotifier,
                        builder: (context, mode, _) => _glassAction(
                          icon: mode == ThemeMode.dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          onTap: () => ThemeService.toggleTheme(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _glassAction(
                        icon: Icons.refresh_rounded,
                        onTap: _loadStatistics,
                      ),
                      const SizedBox(width: 8),
                      _glassAction(
                        icon: Icons.power_settings_new_rounded,
                        onTap: _handleLogout,
                        isDanger: true,
                      ),
                    ],
                  ),
                ],
              ),

              // ── Stats Row ─────────────────────────────────
              if (!_isLoading && !_hasError && _statistics != null) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    _headerStatChip(
                      '${_statistics!.totalRegisteredUsers}',
                      'مستخدم',
                      Icons.people_rounded,
                    ),
                    const SizedBox(width: 8),
                    _headerStatChip(
                      '${_statistics!.totalTeachers}',
                      'معلم',
                      Icons.school_rounded,
                    ),
                    const SizedBox(width: 8),
                    _headerStatChip(
                      '${_statistics!.totalStudents}',
                      'طالب',
                      Icons.person_rounded,
                    ),
                    const SizedBox(width: 8),
                    _headerStatChip(
                      '${_statistics!.totalCourses}',
                      'دورة',
                      Icons.class_rounded,
                    ),
                  ],
                ),
              ],

              if (_isLoading) ...[
                const SizedBox(height: 24),
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassAction({
    required IconData icon,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDanger
              ? Colors.red.withOpacity(0.2)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDanger
                ? Colors.red.withOpacity(0.4)
                : Colors.white.withOpacity(0.25),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDanger ? const Color(0xFFFF6B6B) : Colors.white,
        ),
      ),
    );
  }

  Widget _headerStatChip(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.85), size: 16),
            const SizedBox(height: 5),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withOpacity(0.65),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BOTTOM NAV
  // ═══════════════════════════════════════════════════════
  Widget _buildBottomNav(bool isDark) {
    final items = [
      (Icons.dashboard_rounded, Icons.dashboard_outlined, 'الرئيسية'),
      (Icons.people_alt_rounded, Icons.people_alt_outlined, 'المستخدمون'),
      (Icons.tune_rounded, Icons.tune_outlined, 'النظام'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A2E).withOpacity(0.92)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : AppColors.primary.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final isSelected = _selectedIndex == i;
          final item = items[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected ? item.$1 : item.$2,
                        key: ValueKey(isSelected),
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? Colors.white.withOpacity(0.4)
                                : Colors.black.withOpacity(0.35)),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$3,
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? Colors.white.withOpacity(0.4)
                                : Colors.black.withOpacity(0.35)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BODY
  // ═══════════════════════════════════════════════════════
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'جاري تحميل البيانات...',
              style: GoogleFonts.tajawal(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'تعذّر تحميل البيانات',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _loadStatistics,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'إعادة المحاولة',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_selectedIndex),
        child: [
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildSystemTab(),
        ][_selectedIndex],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('إحصائيات تفصيلية', Icons.bar_chart_rounded),
          const SizedBox(height: 14),

          // Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _statCard(
                'إجمالي المستخدمين',
                '${_statistics?.totalRegisteredUsers ?? 0}',
                Icons.people_rounded,
                AppColors.primary,
                _statistics?.registeredUsersChangeMessage ?? '',
                isDark,
              ),
              _statCard(
                'المعلمون',
                '${_statistics?.totalTeachers ?? 0}',
                Icons.school_rounded,
                AppColors.secondary,
                _statistics?.teachersChangeMessage ?? '',
                isDark,
              ),
              _statCard(
                'الطلاب',
                '${_statistics?.totalStudents ?? 0}',
                Icons.person_rounded,
                AppColors.info,
                _statistics?.studentsChangeMessage ?? '',
                isDark,
              ),
              _statCard(
                'أولياء الأمور',
                '${_statistics?.totalParents ?? 0}',
                Icons.family_restroom_rounded,
                AppColors.success,
                _statistics?.parentsChangeMessage ?? '',
                isDark,
              ),
              _statCard(
                'الدورات',
                '${_statistics?.totalCourses ?? 0}',
                Icons.class_rounded,
                AppColors.warning,
                _statistics?.coursesChangeMessage ?? '',
                isDark,
              ),
              _statCard(
                'الاختبارات',
                '${_statistics?.totalExams ?? 0}',
                Icons.assignment_rounded,
                const Color(0xFF7C3AED),
                _statistics?.examsChangeMessage ?? '',
                isDark,
              ),
            ],
          ),

          const SizedBox(height: 28),
          _sectionHeader('وصول سريع', Icons.flash_on_rounded),
          const SizedBox(height: 14),

          // Quick Access
          Row(
            children: [
              Expanded(
                child: _quickAccessCard(
                  'المعلمون',
                  Icons.school_rounded,
                  AppColors.secondary,
                  isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllTeachersScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAccessCard(
                  'الطلاب',
                  Icons.person_rounded,
                  AppColors.info,
                  isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllStudentsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _quickAccessCard(
                  'أولياء الأمور',
                  Icons.family_restroom_rounded,
                  AppColors.success,
                  isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllParentsScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAccessCard(
                  'المواد',
                  Icons.book_rounded,
                  AppColors.warning,
                  isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminSubjectsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_deleteAccountEnabled) ...[
            const SizedBox(height: 28),
            _dangerZoneCard(isDark),
          ],
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle, // kept for compatibility but not shown
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.2 : 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon only — no subtitle/trending indicator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          // Value & Title only
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
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
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAccessCard(
    String label,
    IconData icon,
    Color color,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: color.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dangerZoneCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المنطقة الحرجة',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                Text(
                  'حذف الحساب بشكل دائم',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.error.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _handleDeleteAccount,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.error),
              ),
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // USERS TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildUsersTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (
        'المعلمون',
        '${_statistics?.totalTeachers ?? 0}',
        Icons.school_rounded,
        AppColors.secondary,
        'إدارة حسابات المعلمين والمساعدين',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllTeachersScreen()),
        ),
      ),
      (
        'الطلاب',
        '${_statistics?.totalStudents ?? 0}',
        Icons.person_rounded,
        AppColors.info,
        'إدارة حسابات الطلاب المسجلين',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllStudentsScreen()),
        ),
      ),
      (
        'أولياء الأمور',
        '${_statistics?.totalParents ?? 0}',
        Icons.family_restroom_rounded,
        AppColors.success,
        'إدارة حسابات أولياء الأمور',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllParentsScreen()),
        ),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('إدارة المستخدمين', Icons.manage_accounts_rounded),
          const SizedBox(height: 14),
          ...List.generate(
            items.length,
            (i) => FadeInUp(
              duration: const Duration(milliseconds: 400),
              delay: Duration(milliseconds: 80 * i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _userManagementCard(
                  title: items[i].$1,
                  count: items[i].$2,
                  icon: items[i].$3,
                  color: items[i].$4,
                  subtitle: items[i].$5,
                  onTap: items[i].$6,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userManagementCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.2 : 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.18),
                    color.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  count,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SYSTEM TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildSystemTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = [
      (
        'إدارة المواد الدراسية',
        'إضافة وتعديل وحذف المواد',
        Icons.book_rounded,
        AppColors.info,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminSubjectsScreen()),
        ),
      ),
      (
        'إعدادات التطبيق',
        'من نحن، فيديو الشرح، معلومات الدعم',
        Icons.settings_applications_rounded,
        AppColors.primary,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAppSettingsScreen()),
        ),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('إعدادات النظام', Icons.settings_rounded),
          const SizedBox(height: 14),
          ...List.generate(
            settings.length,
            (i) => FadeInUp(
              duration: const Duration(milliseconds: 400),
              delay: Duration(milliseconds: 80 * i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _systemCard(
                  title: settings[i].$1,
                  subtitle: settings[i].$2,
                  icon: settings[i].$3,
                  color: settings[i].$4,
                  onTap: settings[i].$5,
                  isDark: isDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Theme toggle card
          _themeToggleCard(isDark),
        ],
      ),
    );
  }

  Widget _systemCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.2 : 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
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
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeToggleCard(bool isDark) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        final isNight = mode == ThemeMode.dark;
        final color = isNight
            ? const Color(0xFF6366F1)
            : const Color(0xFFF59E0B);
        return GestureDetector(
          onTap: () => ThemeService.toggleTheme(),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isNight
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المظهر',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      Text(
                        isNight ? 'الوضع الليلي مفعّل' : 'الوضع النهاري مفعّل',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isNight,
                  onChanged: (_) => ThemeService.toggleTheme(),
                  activeColor: color,
                  activeTrackColor: color.withOpacity(0.3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// WAVE CLIPPER — curves the bottom of the gradient AppBar
// ═══════════════════════════════════════════════════════
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 28);

    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height - 18);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.75, size.height - 38);
    final secondEndPoint = Offset(size.width, size.height - 14);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) => false;
}
