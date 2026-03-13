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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        automaticallyImplyLeading: false, // Hide back button since it's in nav
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
                Icons.play_lesson_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'دوراتي',
              style: GoogleFonts.outfit(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'مقبولة'),
            Tab(text: 'قيد الانتظار'),
            Tab(text: 'مرفوضة'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCourseList(_approvedCourses, 'Approved'),
                _buildCourseList(_pendingCourses, 'Pending'),
                _buildCourseList(_rejectedCourses, 'Rejected'),
              ],
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
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد دورات ${status == 'Approved'
                  ? 'مقبولة'
                  : status == 'Pending'
                  ? 'قيد الانتظار'
                  : 'مرفوضة'}',
              style: GoogleFonts.outfit(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllSubscriptions,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final subscription = courses[index];
          return _buildSubscriptionCard(subscription, status);
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(CourseSubscription sub, String status) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Approved':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'Pending':
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'Rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppColors.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: status == 'Approved'
              ? () {
                  // Debug: Print subscription data
                  print('--- Opening Course ---');
                  print('Course ID: ${sub.courseId}');
                  print('Course Name: ${sub.courseName}');
                  print('Lectures count: ${sub.lectures?.length ?? 0}');
                  if (sub.lectures != null) {
                    print('Lectures data: ${sub.lectures}');
                  }

                  // Create Course object from subscription data with all necessary fields
                  final course = Course(
                    id: sub.courseId,
                    title: sub.courseName,
                    gradeYear: sub.educationStageId,
                    educationStageName: sub.educationStageName,
                    teacherId: 0, // Not needed for student view
                    teacherName: sub.teacherName,
                    lectures: sub.lectures != null
                        ? (sub.lectures as List).map((e) {
                            print('Parsing lecture: $e');
                            // Add courseId to lecture data if missing
                            final lectureData = Map<String, dynamic>.from(e);
                            if (!lectureData.containsKey('courseId')) {
                              lectureData['courseId'] = sub.courseId;
                            }
                            return Lecture.fromJson(lectureData);
                          }).toList()
                        : [],
                  );

                  print(
                    'Course created with ${course.lectures.length} lectures',
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailsScreen(course: course),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.courseName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (sub.teacherName.isNotEmpty)
                        Text(
                          'المعلم: ${sub.teacherName}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                      if (sub.educationStageName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub.educationStageName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status == 'Approved'
                                ? 'مقبولة'
                                : status == 'Pending'
                                ? 'قيد الانتظار'
                                : 'مرفوضة',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow if approved
                if (status == 'Approved')
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
