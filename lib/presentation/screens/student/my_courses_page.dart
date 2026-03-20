import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/course_models.dart';
import 'package:edu_platform_app/data/models/subscription_model.dart';
import 'package:edu_platform_app/data/services/course_service.dart';
import '../shared/course_details/course_details_screen.dart';

class MyCoursesPage extends StatefulWidget {
  final int initialTabIndex;

  const MyCoursesPage({super.key, this.initialTabIndex = 0});

  @override
  State<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends State<MyCoursesPage>
    with SingleTickerProviderStateMixin {
  final _courseService = CourseService();
  late TabController _tabController;
  bool _isLoading = true;
  List<CourseSubscription> _approvedCourses = [];
  List<CourseSubscription> _pendingCourses = [];
  List<CourseSubscription> _rejectedCourses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _fetchAllSubscriptions();
  }

  Future<void> _fetchAllSubscriptions() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _fetchSubscriptions('Approved'),
      _fetchSubscriptions('Pending'),
      _fetchSubscriptions('Rejected'),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSubscriptions(String status) async {
    final response = await _courseService.getSubscriptionsByStatus(status);
    if (mounted && response.succeeded && response.data != null) {
      setState(() {
        if (status == 'Approved') {
          _approvedCourses = response.data!;
        } else if (status == 'Pending') {
          _pendingCourses = response.data!;
        } else if (status == 'Rejected') {
          _rejectedCourses = response.data!;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF1A0A0A), Color(0xFF120808)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(isDark ? 0.08 : 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(isDark ? 0.08 : 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.play_lesson_rounded,
                          color: isDark ? AppColors.primary : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'دوراتي',
                            style: GoogleFonts.tajawal(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'إدارة الكورسات والاشتراكات',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(isDark ? 0.5 : 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141010) : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.primary.withOpacity(0.08) : Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.white.withOpacity(0.4) : AppColors.textSecondary,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: const [
                    Tab(text: 'مقبولة'),
                    Tab(text: 'قيد الانتظار'),
                    Tab(text: 'مرفوضة'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCourseList(_approvedCourses, 'Approved'),
                        _buildCourseList(_pendingCourses, 'Pending'),
                        _buildCourseList(_rejectedCourses, 'Rejected'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseList(List<CourseSubscription> courses, String status) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 56,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد دورات ${status == 'Approved' ? 'مقبولة' : status == 'Pending' ? 'قيد الانتظار' : 'مرفوضة'}',
              style: GoogleFonts.tajawal(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllSubscriptions,
      color: AppColors.primary,
      backgroundColor: Theme.of(context).cardColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final subscription = courses[index];
          return _buildSubscriptionCard(subscription, status);
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(CourseSubscription sub, String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Approved':
        statusColor = const Color(0xFF4ECDC4);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Pending':
        statusColor = const Color(0xFFFFD93D);
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Rejected':
        statusColor = const Color(0xFFFF6B6B);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF141010), Color(0xFF1A0E0E)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isDark ? null : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? statusColor.withOpacity(0.1)
              : Theme.of(context).dividerColor.withOpacity(0.5),
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
          borderRadius: BorderRadius.circular(20),
          onTap: status == 'Approved'
              ? () {
                  final course = Course(
                    id: sub.courseId,
                    title: sub.courseName,
                    gradeYear: sub.educationStageId,
                    educationStageName: sub.educationStageName,
                    teacherId: 0,
                    teacherName: sub.teacherName,
                    lectures: sub.lectures != null
                        ? (sub.lectures as List).map((e) {
                            final lectureData = Map<String, dynamic>.from(e);
                            if (!lectureData.containsKey('courseId')) {
                              lectureData['courseId'] = sub.courseId;
                            }
                            return Lecture.fromJson(lectureData);
                          }).toList()
                        : [],
                  );
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 500),
                      reverseTransitionDuration: const Duration(milliseconds: 400),
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          CourseDetailsScreen(course: course),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.2),
                        statusColor.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.school_rounded, color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.courseName,
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (sub.teacherName.isNotEmpty)
                        Text(
                          sub.teacherName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(isDark ? 0.12 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              status == 'Approved' ? 'مقبولة' : status == 'Pending' ? 'قيد الانتظار' : 'مرفوضة',
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'Approved')
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
