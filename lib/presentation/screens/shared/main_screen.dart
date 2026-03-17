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

  List<Widget> get _pages => [
    _HomeNavigator(navigatorKey: _homeNavigatorKey),
    const SafeArea(child: MyCoursesPage()),
    const SafeArea(child: _ProfilePlaceholder()),
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
        // Removed AppBar to allow pages to manage their own headers
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : AppColors.primary;

    final items = [
      _NavItem(Icons.grid_view_rounded, 'المواد'),
      _NavItem(Icons.play_lesson_rounded, 'دوراتي'),
      _NavItem(Icons.person_rounded, 'الملف'),
      _NavItem(Icons.settings_rounded, 'الإعدادات'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final isSelected = _currentIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (index == 0) {
                  _homeNavigatorKey.currentState
                      ?.popUntil((route) => route.isFirst);
                }
                setState(() {
                  _currentIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 12 : 8,
                  vertical: isSelected ? 8 : 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.primary.withOpacity(0.2) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[index].icon,
                      size: 22,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? Colors.white.withOpacity(0.4)
                              : Colors.white.withOpacity(0.6)),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          items[index].label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
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
              _userName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                  .trim();
              if (_userName!.isEmpty) _userName = 'اسم الطالب';

              _userRole = role;
              _userEmail = data['email'] ?? email;
              _photoUrl =
                  data['studentProfileImageUrl'] ??
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'الملف الشخصي',
              style: GoogleFonts.outfit(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: _photoUrl != null
                              ? Image.network(
                                  _photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Theme.of(context).cardColor,
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 50,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Theme.of(context).cardColor,
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 50,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _userName ?? 'اسم الطالب',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.displayLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _userRole == 'Student' ? 'طالب' : (_userRole ?? 'طالب'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildInfoTile(
                    'البريد الإلكتروني',
                    _userEmail ?? 'غير متوفر',
                  ),
                  const SizedBox(height: 16),
                  if (_studentPhoneNumber != null &&
                      _studentPhoneNumber!.isNotEmpty) ...[
                    _buildInfoTile('رقم هاتف الطالب', _studentPhoneNumber!),
                    const SizedBox(height: 16),
                  ],
                  if (_parentPhoneNumber != null &&
                      _parentPhoneNumber!.isNotEmpty) ...[
                    _buildInfoTile('رقم هاتف ولي الأمر', _parentPhoneNumber!),
                    const SizedBox(height: 16),
                  ],
                  if (_governorate != null && _governorate!.isNotEmpty) ...[
                    _buildInfoTile('المحافظة', _governorate!),
                    const SizedBox(height: 16),
                  ],
                  if (_city != null && _city!.isNotEmpty) ...[
                    _buildInfoTile('المدينة', _city!),
                    const SizedBox(height: 16),
                  ],
                  _buildInfoTile(
                    'نوع الحساب',
                    _userRole == 'Student' ? 'طالب' : (_userRole ?? 'طالب'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
