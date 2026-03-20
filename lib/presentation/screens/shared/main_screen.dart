import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/data/services/auth_service.dart';
import 'package:edu_platform_app/data/services/google_signin_service.dart';
import 'package:edu_platform_app/data/services/student_service.dart';
import 'package:edu_platform_app/data/services/notification_service.dart';
import 'settings_screen.dart';
import '../auth/login_screen.dart';
import '../student/my_courses_page.dart';
import '../student/select_subject_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _tokenService = TokenService();
  final GlobalKey<NavigatorState> _homeNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Process any pending notification that launched the app from terminated state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.processPendingNotification();
    });
  }

  List<Widget> get _pages => [
        _HomeNavigator(navigatorKey: _homeNavigatorKey),
        const MyCoursesPage(),
        const _ProfilePlaceholder(),
        SafeArea(
          child: SettingsScreen(
            onLogout: _handleLogout,
            onDeleteAccount: _handleDeleteAccount,
          ),
        ),
      ];

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

    // Log out from notifications (unsubscribe from topics)
    try {
      await NotificationService.unsubscribeFromAllTopics();
    } catch (e) {
      print('Error unsubscribing from topics on logout: $e');
    }

    // Clear local tokens
    await _tokenService.clearTokens();

    // Sign out from Google to Force account picker next time
    try {
      await GoogleSignInService().signOut();
    } catch (e) {
      print('Error signing out from Google: $e');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
                color: Theme.of(context).textTheme.bodyLarge?.color,
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
                color: Theme.of(context).textTheme.bodyMedium?.color,
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
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
                color: Theme.of(context).textTheme.bodyLarge?.color,
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.inter(
                color: Theme.of(context).textTheme.bodyMedium?.color,
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        // Removed AppBar to allow pages to manage their own headers
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _pages[_currentIndex],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFD93D),
      const Color(0xFF6C5CE7),
    ];

    final items = [
      _NavItem(Icons.grid_view_rounded, 'المواد'),
      _NavItem(Icons.play_lesson_rounded, 'دوراتي'),
      _NavItem(Icons.person_rounded, 'الملف'),
      _NavItem(Icons.settings_rounded, 'الإعدادات'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        height: 72,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0D0D0D), Color(0xFF1A0508)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.9)],
                ),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withOpacity(0.15)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.primary.withOpacity(0.06)
                  : AppColors.primary.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (index) {
            final isSelected = _currentIndex == index;
            final itemColor = colors[index];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (index == 0) {
                    _homeNavigatorKey.currentState
                        ?.popUntil((route) => route.isFirst);
                  }
                  setState(() {
                    _currentIndex = index;
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: isSelected ? 1.0 : 0.85),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.all(isSelected ? 10 : 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? itemColor.withOpacity(isDark ? 0.18 : 0.22)
                                  : Colors.transparent,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: itemColor.withOpacity(0.3),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              items[index].icon,
                              size: isSelected ? 22 : 20,
                              color: isSelected
                                  ? itemColor
                                  : (isDark
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.6)),
                            ),
                          ),
                        );
                      },
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          items[index].label,
                          style: GoogleFonts.tajawal(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: itemColor,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withOpacity(0.15)
                                : Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _HomeNavigator extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const _HomeNavigator({required this.navigatorKey});

  @override
  State<_HomeNavigator> createState() => _HomeNavigatorState();
}

class _HomeNavigatorState extends State<_HomeNavigator> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final navigator = widget.navigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return false;
        }
        return true;
      },
      child: Navigator(
        key: widget.navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const SelectSubjectScreen(),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PROFILE PAGE (Student)
// ═══════════════════════════════════════════════════════════════════════

class _ProfilePlaceholder extends StatefulWidget {
  const _ProfilePlaceholder();

  @override
  State<_ProfilePlaceholder> createState() => _ProfilePlaceholderState();
}

class _ProfilePlaceholderState extends State<_ProfilePlaceholder> {
  final _tokenService = TokenService();
  final _studentService = StudentService();

  String? _userName;
  String? _userRole;
  String? _userEmail;
  String? _photoUrl;
  String? _studentPhoneNumber;
  String? _parentPhoneNumber;
  String? _governorate;
  String? _city;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final role = await _tokenService.getRole();
    final email = await _tokenService.getUserEmail();
    final photo = await _tokenService.getPhotoUrl();

    // Fetch student profile from API
    if (role == 'Student') {
      try {
        final response = await _studentService.getProfile();
        if (response.succeeded && response.data != null) {
          final data = response.data!;

          if (mounted) {
            setState(() {
              _userName =
                  '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
              if (_userName!.isEmpty) _userName = 'اسم الطالب';

              _userRole = role;
              _userEmail = data['email'] ?? email;
              _photoUrl = data['studentProfileImageUrl'] ??
                  photo; // Use studentProfileImageUrl from API
              _studentPhoneNumber = data['studentPhoneNumber'];
              _parentPhoneNumber = data['parentPhoneNumber'];
              _governorate = data['governorate'];
              _city = data['city'];
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        print('Error loading student profile: $e');
      }
    }

    // Fallback to token data if API call fails
    final name = await _tokenService.getUserName();

    if (mounted) {
      setState(() {
        _userName = name;
        _userRole = role;
        _userEmail = email;
        _photoUrl = photo;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A0A0A), Color(0xFF150808), Color(0xFF0D0505)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
                child: Column(
                  children: [
                    // Profile Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? const LinearGradient(
                                colors: [Color(0xFF1A0A0A), Color(0xFF120808)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? AppColors.primary.withOpacity(0.12)
                              : Colors.transparent,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(isDark ? 0.08 : 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Avatar
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: SizedBox(
                                width: 90,
                                height: 90,
                                child: _photoUrl != null
                                    ? Image.network(
                                        _photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          color: Colors.white.withOpacity(0.1),
                                          child: const Icon(Icons.person_rounded,
                                              size: 45, color: Colors.white70),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.white.withOpacity(0.1),
                                        child: const Icon(Icons.person_rounded,
                                            size: 45, color: Colors.white70),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _userName ?? 'اسم الطالب',
                            style: GoogleFonts.tajawal(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(isDark ? 0.08 : 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _userRole == 'Student' ? '🎓 طالب' : (_userRole ?? 'طالب'),
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info Section
                    Container(
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? const LinearGradient(
                                colors: [Color(0xFF141010), Color(0xFF1A0E0E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isDark ? null : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.primary.withOpacity(0.1)
                              : Theme.of(context).dividerColor.withOpacity(0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.email_outlined,
                            'البريد الإلكتروني',
                            _userEmail ?? 'غير متوفر',
                            const Color(0xFF74B9FF),
                            showDivider: true,
                          ),
                          if (_studentPhoneNumber != null &&
                              _studentPhoneNumber!.isNotEmpty)
                            _buildInfoRow(
                              Icons.phone_android_rounded,
                              'رقم هاتف الطالب',
                              _studentPhoneNumber!,
                              const Color(0xFF4ECDC4),
                              showDivider: true,
                            ),
                          if (_parentPhoneNumber != null &&
                              _parentPhoneNumber!.isNotEmpty)
                            _buildInfoRow(
                              Icons.phone_rounded,
                              'رقم هاتف ولي الأمر',
                              _parentPhoneNumber!,
                              const Color(0xFFFFD93D),
                              showDivider: true,
                            ),
                          if (_governorate != null && _governorate!.isNotEmpty)
                            _buildInfoRow(
                              Icons.location_city_rounded,
                              'المحافظة',
                              _governorate!,
                              const Color(0xFF6C5CE7),
                              showDivider: true,
                            ),
                          if (_city != null && _city!.isNotEmpty)
                            _buildInfoRow(
                              Icons.place_rounded,
                              'المدينة',
                              _city!,
                              const Color(0xFFFF6B6B),
                              showDivider: true,
                            ),
                          _buildInfoRow(
                            Icons.badge_rounded,
                            'نوع الحساب',
                            _userRole == 'Student' ? 'طالب' : (_userRole ?? 'طالب'),
                            const Color(0xFFA29BFE),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    bool showDivider = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              height: 1,
              color: isDark
                  ? AppColors.primary.withOpacity(0.06)
                  : Theme.of(context).dividerColor.withOpacity(0.3),
            ),
          ),
      ],
    );
  }
}
