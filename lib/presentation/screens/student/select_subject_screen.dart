import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/subject_model.dart';
import 'package:edu_platform_app/data/services/subject_service.dart';
import 'package:edu_platform_app/data/services/user_notification_service.dart';
import 'select_teacher_screen.dart';
import 'package:edu_platform_app/presentation/screens/shared/notifications_screen.dart';

class SelectSubjectScreen extends StatefulWidget {
  const SelectSubjectScreen({super.key});

  @override
  State<SelectSubjectScreen> createState() => _SelectSubjectScreenState();
}

class _SelectSubjectScreenState extends State<SelectSubjectScreen>
    with SingleTickerProviderStateMixin {
  final _subjectService = SubjectService();
  final _notificationService = UserNotificationService();
  bool _isLoading = true;
  List<Subject> _subjects = [];
  String? _error;
  int _unreadCount = 0;

  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
    _fetchUnreadCount();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  Future<void> _fetchUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _subjectService.getSubjects();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.succeeded && response.data != null) {
          _subjects = response.data!;
        } else {
          _error = response.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildAnimatedBackground(size),
          _buildDecorativeOrbs(size),
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_subjects.isEmpty) return _buildEmptyState();

    return _buildContent();
  }

  Widget _buildAnimatedBackground(Size size) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).cardColor,
                Theme.of(context).scaffoldBackgroundColor,
              ],
              stops: [
                0.0,
                0.5 + 0.1 * math.sin(_backgroundController.value * 2 * math.pi),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDecorativeOrbs(Size size) {
    return Stack(
      children: [
        Positioned(
          top: -size.height * 0.1,
          right: -size.width * 0.2,
          child: AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  20 * math.sin(_backgroundController.value * 2 * math.pi),
                  20 * math.cos(_backgroundController.value * 2 * math.pi),
                ),
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.meshBlue.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Theme.of(context).primaryColor),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل المواد...',
            style: GoogleFonts.inter(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل المواد',
            style: GoogleFonts.inter(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          TextButton(
            onPressed: _fetchSubjects,
            child: Text(
              'إعادة المحاولة',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'لم يتم العثور على مواد',
        style: GoogleFonts.inter(
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  // --- NEW WATERMARK DESIGN IMPLEMENTATION ---

  Widget _buildContent() {
    final filteredSubjects = _subjects;
    final size = MediaQuery.of(context).size;

    return RefreshIndicator(
      onRefresh: _fetchSubjects,
      color: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: filteredSubjects.isEmpty
                ? SliverToBoxAdapter(
                    child: Text(
                      'لا توجد مواد تطابق بحثك',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 16,
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final subject = filteredSubjects[index];
                      return FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: Duration(milliseconds: 100 * index),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: AspectRatio(
                            aspectRatio: 15 / 8,
                            child: _buildSubjectTile(subject, index),
                          ),
                        ),
                      );
                    }, childCount: filteredSubjects.length),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo_icon.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'منصة بوصلة - Bosla',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تصفح',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'المواد',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color:
                              Theme.of(context).textTheme.displayMedium?.color,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Notifications Button
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          ).then((_) => _fetchUnreadCount());
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: Icon(
                                Icons.notifications_rounded,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Theme.of(context).primaryColor,
                                size: 24,
                              ),
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).scaffoldBackgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          '${_subjects.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getSubjectIcon(String subjectName) {
    final name = subjectName.toLowerCase();
    if (name.contains('math')) return Icons.calculate_rounded;
    if (name.contains('physic')) return Icons.bolt_rounded;
    if (name.contains('chem')) return Icons.science_rounded;
    if (name.contains('bio')) return Icons.spa_rounded;
    if (name.contains('hist')) return Icons.account_balance_rounded;
    if (name.contains('geo')) return Icons.public_rounded;
    if (name.contains('eng')) return Icons.translate_rounded;
    if (name.contains('arab')) return Icons.menu_book_rounded;
    if (name.contains('tech') || name.contains('comp'))
      return Icons.computer_rounded;
    if (name.contains('art')) return Icons.palette_rounded;
    return Icons.school_rounded;
  }

  Widget _buildSubjectTile(Subject subject, int index) {
    final baseColor =
        AppColors.subjectColors[index % AppColors.subjectColors.length][0];
    final darkColor =
        AppColors.subjectColors[index % AppColors.subjectColors.length][1];
    final icon = _getSubjectIcon(subject.name);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectTeacherScreen(
              subjectId: subject.id,
              subjectName: subject.name,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Subject Image as Background (if available)
              if (subject.subjectImageUrl != null &&
                  subject.subjectImageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    subject.subjectImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              baseColor.withOpacity(0.15),
                              Colors.transparent,
                              darkColor.withOpacity(0.1),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // 2. Dark overlay for text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Mesh Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        baseColor.withOpacity(0.2),
                        Colors.transparent,
                        darkColor.withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Watermark Icon (Top Right)
              Positioned(
                top: -20,
                right: -20,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    icon,
                    size: 100,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),

              // 5. Content
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon Circle with subtle background
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: baseColor.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(icon, size: 24, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subject Name
                      Text(
                        subject.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Arrow / Action
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'استكشاف',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ],
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
    );
  }
}
