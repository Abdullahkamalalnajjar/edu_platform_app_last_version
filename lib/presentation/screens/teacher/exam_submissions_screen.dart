import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/core/utils/score_utils.dart';
import 'package:edu_platform_app/data/models/course_models.dart';
import 'package:edu_platform_app/data/services/course_service.dart';
import 'package:edu_platform_app/data/services/teacher_service.dart';
import 'package:edu_platform_app/presentation/screens/student/student_exam_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ExamSubmissionsScreen extends StatefulWidget {
  final int lectureId;
  final String lectureTitle;
  final int? examId;

  const ExamSubmissionsScreen({
    super.key,
    required this.lectureId,
    required this.lectureTitle,
    this.examId,
  });

  @override
  State<ExamSubmissionsScreen> createState() => _ExamSubmissionsScreenState();
}

class _ExamSubmissionsScreenState extends State<ExamSubmissionsScreen> {
  final _courseService = CourseService();
  final _teacherService = TeacherService();
  bool _isLoading = true;
  List<ExamSubmission> _submissions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = widget.examId != null
        ? await _courseService.getExamSubmissionsByExamId(widget.examId!)
        : await _courseService.getExamSubmissions(widget.lectureId);
    if (response.succeeded) {
      setState(() {
        _submissions = response.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAutoSubmit() async {
    if (widget.examId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تسليم تلقائي'),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسليم جميع المحاولات المفتوحة لهذا الاختبار تلقائياً؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري معالجة التسليم التلقائي...')),
        );
      }

      final response = await _teacherService.autoSubmitExam(widget.examId!);

      if (mounted) {
        if (response.succeeded) {
          final data = response.data;
          final meta = response.meta ?? 'تمت العملية';
          // Show detailed message
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text(
                'تمت العملية بنجاح',
                style: TextStyle(color: AppColors.success),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta),
                  const SizedBox(height: 8),
                  if (data != null) ...[
                    Text(
                      'الطلاب الذين سلموا مسبقاً: ${data['totalStudentsSubmitted']}',
                    ),
                    Text(
                      'تم التسليم التلقائي لـ: ${data['totalStudentsAutoSubmitted']}',
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
          _fetchSubmissions(); // Refresh list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: ${response.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCorrectAll() async {
    if (widget.examId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تصحيح الكل'),
        content: const Text(
          'هل أنت متأكد من رغبتك في تصحيح جميع تسليمات هذا الاختبار؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري معالجة التصحيح...')),
        );
      }

      final response = await _teacherService.correctAllExams(widget.examId!);

      if (mounted) {
        if (response.succeeded) {
          final correctedCount = response.data;
          final message = response.message.isNotEmpty
              ? response.message
              : (correctedCount != null
                  ? 'تم تصحيح $correctedCount اختبار بنجاح'
                  : 'تمت العملية بنجاح');
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text(
                'تمت العملية بنجاح',
                style: TextStyle(color: AppColors.success),
              ),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
          _fetchSubmissions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: ${response.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCorrectStudent(int studentId) async {
    if (widget.examId == null) return;

    final response = await _teacherService.correctExamForStudent(
      widget.examId!,
      studentId,
    );

    if (mounted) {
      if (response.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصحيح المحاولة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchSubmissions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${response.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceLight : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final total = _submissions.length;
    final pending =
        _submissions.where((s) => s.pendingGradingAnswers > 0).length;
    final graded = total - pending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'كل الطلاب',
              total.toString(),
              Icons.people_outline,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatItem(
              'بانتظار التصحيح',
              pending.toString(),
              Icons.pending_outlined,
              AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatItem(
              'تم التصحيح',
              graded.toString(),
              Icons.check_circle_outline,
              AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'تسليمات: ${widget.lectureTitle}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.examId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                onPressed: _handleAutoSubmit,
                icon: const Icon(Icons.auto_mode, color: AppColors.primary),
                label: const Text(
                  'تسليم تلقائي',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                ),
              ),
            ),
          if (widget.examId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                onPressed: _handleCorrectAll,
                icon: const Icon(Icons.check_circle_outline,
                    color: AppColors.success),
                label: const Text(
                  'تصحيح الكل',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.success.withOpacity(0.1),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchSubmissions,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _submissions.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد تسليمات بعد',
                        style:
                            GoogleFonts.inter(color: AppColors.textSecondary),
                      ),
                    )
                  : Column(
                      children: [
                        _buildSummaryCards(),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 600) {
                                return RefreshIndicator(
                                  onRefresh: _fetchSubmissions,
                                  child: GridView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 400,
                                      childAspectRatio: 1.5,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    itemCount: _submissions.length,
                                    itemBuilder: (context, index) {
                                      final submission = _submissions[index];
                                      return _buildSubmissionCard(submission);
                                    },
                                  ),
                                );
                              } else {
                                return RefreshIndicator(
                                  onRefresh: _fetchSubmissions,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    itemCount: _submissions.length,
                                    itemBuilder: (context, index) {
                                      final submission = _submissions[index];
                                      return _buildSubmissionCard(submission);
                                    },
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildSubmissionCard(ExamSubmission submission) {
    String submittedAt = 'غير معروف';
    if (submission.submittedAt != null) {
      final dt = submission.submittedAt!.toLocal();
      submittedAt =
          '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          submission.studentName,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              submission.studentEmail ?? '',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 12,
              ),
            ),
            if (submission.studentPhoneNumber != null &&
                submission.studentPhoneNumber!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_iphone_rounded,
                          size: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'الطالب: ${submission.studentPhoneNumber}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () async {
                        final phoneNumber = submission.studentPhoneNumber!;
                        final uri = Uri.parse('tel:$phoneNumber');
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تعذر إجراء الاتصال'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error launching dialer: $e');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF25D366).withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_in_talk_rounded,
                              size: 14,
                              color: Color(0xFF25D366),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'اتصال',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF25D366),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (submission.parentPhoneNumber != null &&
                submission.parentPhoneNumber!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ولي الأمر: ${submission.parentPhoneNumber}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () async {
                        final phoneNumber = submission.parentPhoneNumber!;
                        final uri = Uri.parse('tel:$phoneNumber');
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            // Fallback or error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تعذر إجراء الاتصال'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error launching dialer: $e');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF25D366,
                          ).withOpacity(0.1), // WhatsApp/Phone Green
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF25D366).withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_in_talk_rounded,
                              size: 14,
                              color: Color(0xFF25D366),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'اتصال',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF25D366),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  submittedAt,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (submission.gradedByName != null &&
                submission.gradedByName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 12,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'صححه: ${submission.gradedByName}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatScoreWithMax(
                submission.currentTotalScore,
                submission.maxScore,
              ),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
            if (submission.pendingGradingAnswers > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'بانتظار التصحيح (${submission.pendingGradingAnswers})',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'تم التصحيح',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (widget.examId != null)
              InkWell(
                onTap: () => _handleCorrectStudent(submission.studentId),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'تصحيح',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentExamScreen(
                lectureId: widget.lectureId,
                examId: widget.examId,
                lectureTitle: widget.lectureTitle,
                isTeacher: true,
                viewingStudentId: submission.studentId,
                viewingStudentName: submission.studentName,
              ),
            ),
          ).then((_) => _fetchSubmissions());
        },
      ),
    );
  }
}
