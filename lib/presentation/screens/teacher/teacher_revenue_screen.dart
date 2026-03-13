import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/teacher_revenue_model.dart';
import 'package:edu_platform_app/data/services/teacher_service.dart';

class TeacherRevenueScreen extends StatefulWidget {
  final int teacherId;
  final String teacherName;

  const TeacherRevenueScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherRevenueScreen> createState() => _TeacherRevenueScreenState();
}

class _TeacherRevenueScreenState extends State<TeacherRevenueScreen> {
  final _teacherService = TeacherService();
  bool _isLoading = true;
  TeacherRevenueResponse? _revenueData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRevenue();
  }

  Future<void> _fetchRevenue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _teacherService.getTeacherRevenue(widget.teacherId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.succeeded && response.data != null) {
          _revenueData = response.data;
        } else {
          _error = response.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'إحصائيات الأرباح',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _error ?? 'حدث خطأ',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchRevenue,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_revenueData == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _fetchRevenue,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            _buildSummaryCards(),
            const SizedBox(height: 24),

            // Courses List
            Text(
              'تفاصيل الدورات',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            ..._groupedCourses.map((course) => _buildCourseCard(course)),
          ],
        ),
      ),
    );
  }

  List<CourseRevenueDetail> get _groupedCourses {
    if (_revenueData == null) return [];

    final groupedMap = <String, CourseRevenueDetail>{};

    for (var course in _revenueData!.courses) {
      // Use courseTitle as key to merge duplicates visually
      final key = course.courseTitle;

      if (groupedMap.containsKey(key)) {
        final existing = groupedMap[key]!;
        groupedMap[key] = CourseRevenueDetail(
          courseId: existing.courseId,
          courseTitle: existing.courseTitle,
          coursePrice: existing.coursePrice,
          approvedSubscriptions:
              existing.approvedSubscriptions + course.approvedSubscriptions,
          courseRevenue: existing.courseRevenue + course.courseRevenue,
          students: [...existing.students, ...course.students],
        );
      } else {
        groupedMap[key] = course;
      }
    }
    return groupedMap.values.toList();
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: FadeInLeft(
            duration: const Duration(milliseconds: 600),
            child: _buildSummaryCard(
              title: 'إجمالي الأرباح',
              value: '${_revenueData!.totalRevenue.toStringAsFixed(0)} ج.م',
              icon: Icons.attach_money_rounded,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FadeInRight(
            duration: const Duration(milliseconds: 600),
            child: _buildSummaryCard(
              title: 'عدد الاشتراكات',
              value: '${_revenueData!.totalApprovedSubscriptions}',
              icon: Icons.people_rounded,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CourseRevenueDetail course) {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              course.courseTitle,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _buildInfoChip(
                    '${course.courseRevenue.toStringAsFixed(0)} ج.م',
                    Icons.monetization_on_rounded,
                    AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    '${course.approvedSubscriptions} طالب',
                    Icons.people_rounded,
                    AppColors.primary,
                  ),
                ],
              ),
            ),
            children: [
              if (course.students.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'لا يوجد طلاب مشتركين',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ...course.students.map((student) => _buildStudentTile(student)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(StudentRevenueDetail student) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'ar');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.primary.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.studentName,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(student.subscriptionDate),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${student.paidAmount.toStringAsFixed(0)} ج.م',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
