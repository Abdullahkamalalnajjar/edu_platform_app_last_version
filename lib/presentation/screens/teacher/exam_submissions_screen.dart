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
  final int? courseId;

  const ExamSubmissionsScreen({
    super.key,
    required this.lectureId,
    required this.lectureTitle,
    this.examId,
    this.courseId,
  });

  @override
  State<ExamSubmissionsScreen> createState() => _ExamSubmissionsScreenState();
}

class _ExamSubmissionsScreenState extends State<ExamSubmissionsScreen> {
  final _courseService = CourseService();
  final _teacherService = TeacherService();
  bool _isLoading = true;
  List<ExamSubmission> _submissions = [];
  List<ExamSubmission> _filteredSubmissions = [];
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  NonSubmittedStudentsResponse? _nonSubmittedResponse;
  bool _showingNonSubmittedOnly = false;
  bool _filterPendingOnly = false;
  int _totalManualQuestions = -1; // -1 = not fetched yet
  int? _ungradedCount; // from backend ungraded-submissions endpoint
  double _enrichProgress = 0.0; // 0.0 to 1.0
  bool _isEnriching = false;

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
    _fetchNonSubmittedStats();
    _fetchManualQuestionCount();
    _fetchUngradedCount();
    _searchController.addListener(_onSearchChanged);
  }

  /// Fetch exam questions once to count how many need manual grading.
  /// Only TextAnswer and ImageAnswer need manual grading — MCQ is auto-graded.
  Future<void> _fetchManualQuestionCount() async {
    final examId = widget.examId;
    if (examId == null) return;
    try {
      final response = await _courseService.getExamById(examId);
      if (mounted && response.succeeded && response.data != null) {
        final questions = response.data!.questions;
        final count = questions.where((q) {
          return q.answerType == 'TextAnswer' || q.answerType == 'ImageAnswer';
        }).length;
        setState(() {
          _totalManualQuestions = count;
          _applySearch(); // re-apply filter with correct count
        });
      }
    } catch (_) {}
  }

  /// Returns the real pending manual count for a submission.
  /// Considers both server-reported values and local knowledge of manual question count.
  int _manualPending(ExamSubmission s) {
    // If we know the exact manual question count, compute accurately
    if (_totalManualQuestions > 0) {
      final pending = (_totalManualQuestions - s.manuallyGradedAnswers)
          .clamp(0, _totalManualQuestions);
      return pending;
    }
    // If server explicitly says graded, trust it
    if (s.isGraded) return 0;
    // Use server's manual pending value
    if (s.manualPendingGradingAnswers > 0) return s.manualPendingGradingAnswers;
    // Use server's general pending value
    if (s.pendingGradingAnswers > 0) return s.pendingGradingAnswers;
    // No info available
    return 0;
  }

  Future<void> _fetchNonSubmittedStats() async {
    if (widget.examId == null || widget.courseId == null) return;

    final response = await _courseService.getNonSubmittedStudents(
      examId: widget.examId!,
      courseId: widget.courseId!,
    );

    if (mounted && response.succeeded) {
      setState(() {
        _nonSubmittedResponse = response.data;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applySearch();
    });
  }

  void _applySearch() {
    List<ExamSubmission> baseList = List.from(_submissions);

    if (_showingNonSubmittedOnly) {
      // This is tricky because _submissions only contains those who DID submit.
      // We might need to handle the display separately or merge them.
    }

    // Apply pending filter — show only ungraded submissions (isGraded == false from backend)
    if (_filterPendingOnly) {
      baseList = baseList.where((s) {
        final hasGradedBy =
            s.gradedByName != null && s.gradedByName!.isNotEmpty;
        if (hasGradedBy) return false; // already graded by someone
        // Use isGraded field from backend
        if (!s.isGraded) return true;
        return false;
      }).toList();
    }

    if (_searchQuery.isEmpty) {
      _filteredSubmissions = baseList;
    } else {
      _filteredSubmissions = baseList.where((s) {
        final name = s.studentName.toLowerCase();
        final email = (s.studentEmail ?? '').toLowerCase();
        final phone = (s.studentPhoneNumber ?? '').toLowerCase();
        return name.contains(_searchQuery) ||
            email.contains(_searchQuery) ||
            phone.contains(_searchQuery);
      }).toList();
    }
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
        _applySearch();
        _isLoading = false;
      });
      // Enrich submissions with gradedByName from detailed results
      _enrichSubmissionsWithGradedByName();
      // Refresh ungraded count from backend
      _fetchUngradedCount();
    } else {
      setState(() {
        _error = response.message;
        _isLoading = false;
      });
    }
  }

  /// Fetches detailed exam results for each submission to extract gradedByName.
  /// The submissions list API doesn't return gradedByName, but the individual
  /// student score API does (inside studentAnswers).
  Future<void> _enrichSubmissionsWithGradedByName() async {
    final examId = widget.examId;
    if (examId == null || _submissions.isEmpty) return;

    setState(() {
      _isEnriching = true;
      _enrichProgress = 0.0;
    });

    final total = _submissions.length;
    int completed = 0;
    final gradedByNameMap = <int, String>{};

    // Process submissions and track progress
    for (final submission in _submissions) {
      try {
        final result = await _courseService.getStudentExamResult(
          examId,
          studentId: submission.studentId,
        );
        if (result.succeeded && result.data != null) {
          String? gradedByName;
          for (final answer in result.data!.studentAnswers) {
            if (answer.gradedByName != null &&
                answer.gradedByName!.isNotEmpty) {
              gradedByName = answer.gradedByName;
              break;
            }
          }
          gradedByName ??= result.data!.gradedByName;
          if (gradedByName != null && gradedByName.isNotEmpty) {
            gradedByNameMap[submission.studentId] = gradedByName;
          }
        }
      } catch (e) {
        print('Error fetching result for student ${submission.studentId}: $e');
      }

      completed++;
      if (mounted) {
        setState(() {
          _enrichProgress = completed / total;
        });
      }
    }

    if (mounted && gradedByNameMap.isNotEmpty) {
      setState(() {
        _submissions = _submissions.map((s) {
          final name = gradedByNameMap[s.studentId];
          if (name != null &&
              (s.gradedByName == null || s.gradedByName!.isEmpty)) {
            return s.copyWith(gradedByName: name);
          }
          return s;
        }).toList();
        _applySearch();
      });
    }

    if (mounted) {
      setState(() {
        _isEnriching = false;
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
    Color color, {
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.15)
              : (isDark ? AppColors.surfaceLight : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isActive ? 0.15 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(isActive ? 0.25 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fetch ungraded submissions count from the backend.
  Future<void> _fetchUngradedCount() async {
    final examId = widget.examId;
    if (examId == null) return;
    try {
      final response = await _courseService.getUngradedSubmissionsCount(examId);
      if (mounted && response.succeeded && response.data != null) {
        setState(() {
          _ungradedCount = response.data;
        });
      }
    } catch (_) {}
  }

  Widget _buildSummaryCards() {
    final submittedCount =
        _nonSubmittedResponse?.submittedCount ?? _submissions.length;
    final totalEnrolled =
        _nonSubmittedResponse?.totalEnrolledStudents ?? _submissions.length;
    final nonSubmitted = _nonSubmittedResponse?.nonSubmittedCount ?? 0;
    // Use the backend ungraded count directly instead of computing locally
    final pendingCount =
        _ungradedCount ?? _submissions.where((s) => !s.isGraded).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'إجمالي الطلاب',
              totalEnrolled.toString(),
              Icons.people_alt,
              AppColors.info,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStatItem(
              'تم التسليم',
              submittedCount.toString(),
              Icons.check_circle_outline,
              AppColors.success,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStatItem(
              'لم يسلموا',
              nonSubmitted.toString(),
              Icons.error_outline,
              AppColors.error,
              onTap: nonSubmitted > 0 ? _showNonSubmittedStudents : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildStatItem(
              'بانتظار التصحيح',
              pendingCount.toString(),
              Icons.pending_outlined,
              AppColors.warning,
              onTap: pendingCount > 0
                  ? () {
                      setState(() {
                        _filterPendingOnly = !_filterPendingOnly;
                        _applySearch();
                      });
                    }
                  : null,
              isActive: _filterPendingOnly,
            ),
          ),
        ],
      ),
    );
  }

  void _showNonSubmittedStudents() {
    if (_nonSubmittedResponse == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline_rounded,
                        color: AppColors.error),
                    const SizedBox(width: 12),
                    Text(
                      'طلاب لم يسلموا (${_nonSubmittedResponse!.nonSubmittedCount})',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _nonSubmittedResponse!.nonSubmittedStudents.length,
                  itemBuilder: (context, index) {
                    final student =
                        _nonSubmittedResponse!.nonSubmittedStudents[index];
                    return _buildNonSubmittedStudentCard(student);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNonSubmittedStudentCard(NonSubmittedStudentDto student) {
    String? subscriptionDate;
    if (student.subscriptionCreatedAt != null) {
      final dt = student.subscriptionCreatedAt!.toLocal();
      subscriptionDate =
          '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          student.studentName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(student.studentEmail,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (subscriptionDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'تاريخ الاشتراك: $subscriptionDate',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPhoneChip(
                    student.studentPhone, 'الطالب', Icons.phone_iphone),
                const SizedBox(width: 8),
                _buildPhoneChip(
                    student.parentPhone, 'ولي الأمر', Icons.family_restroom),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneChip(String phone, String label, IconData icon) {
    if (phone.isEmpty) return const SizedBox();
    return InkWell(
      onTap: () => _makeCall(phone),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ابحث باسم الطالب، الإيميل، أو رقم الهاتف...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.glassBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.glassBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEnrichProgressBar() {
    final percent = (_enrichProgress * 100).toInt();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = (_enrichProgress * _submissions.length).toInt();
    final total = _submissions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.primary.withOpacity(0.12),
                    AppColors.primary.withOpacity(0.05),
                  ]
                : [
                    AppColors.primary.withOpacity(0.06),
                    AppColors.primary.withOpacity(0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.12),
          ),
        ),
        child: Row(
          children: [
            // Circular percentage
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _enrichProgress,
                    strokeWidth: 3,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                  Text(
                    '$percent',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Text + progress bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جاري جلب بيانات المصححين',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      Text(
                        '$completed / $total',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        // Background
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        // Gradient fill
                        FractionallySizedBox(
                          widthFactor: _enrichProgress,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  Color(0xFF6C63FF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: Theme.of(context).iconTheme.color,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Theme.of(context).cardColor,
              onSelected: (value) {
                if (value == 'auto_submit') {
                  _handleAutoSubmit();
                } else if (value == 'correct_all') {
                  _handleCorrectAll();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'auto_submit',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_mode,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'تسليم تلقائي',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'correct_all',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'تصحيح الكل',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              : Column(
                  children: [
                    _buildSummaryCards(),
                    if (_submissions.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            'لا يوجد تسليمات بعد',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else ...[
                      _buildSearchBar(),
                      if (_isEnriching) _buildEnrichProgressBar(),
                      if (_filteredSubmissions.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 56,
                                  color:
                                      AppColors.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد نتائج للبحث',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
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
                                    itemCount: _filteredSubmissions.length,
                                    itemBuilder: (context, index) {
                                      final submission =
                                          _filteredSubmissions[index];
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
                                    itemCount: _filteredSubmissions.length,
                                    itemBuilder: (context, index) {
                                      final submission =
                                          _filteredSubmissions[index];
                                      return _buildSubmissionCard(submission);
                                    },
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSubmissionCard(ExamSubmission submission) {
    print(
        '📋 Submission: ${submission.studentName} | gradedByName: "${submission.gradedByName}" | manuallyGraded: ${submission.manuallyGradedAnswers} | pending: ${submission.pendingGradingAnswers}');
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
            // Status badge (handles graded/pending display)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusBadge(submission),
                ],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _handleDeleteSubmission(submission),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error,
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
          );
        },
      ),
    );
  }

  Future<void> _handleDeleteSubmission(ExamSubmission submission) async {
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
            Expanded(
              child: Text(
                'حذف النتيجة',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف نتيجة "${submission.studentName}"؟\n\nلا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5,
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
              'حذف',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await _courseService.deleteExamResult(
      submission.studentExamResultId,
    );

    if (mounted) {
      if (response.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف نتيجة ${submission.studentName}'),
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

  Widget _buildStatusBadge(ExamSubmission submission) {
    final hasGradedBy =
        submission.gradedByName != null && submission.gradedByName!.isNotEmpty;
    final manualPending = _manualPending(submission);

    // Case 1: Has a grader name — definitely graded
    if (hasGradedBy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'تم التصحيح ✓ بواسطة: ${submission.gradedByName}',
          style: const TextStyle(
            color: AppColors.success,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Case 2: Backend explicitly says graded via isGraded flag
    if (submission.isGraded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'تم التصحيح ✓',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Case 3: Student submitted without answering (totalAnswers=0, no pending)
    // This is NOT graded yet — show pending
    if (submission.totalAnswers == 0 && submission.pendingGradingAnswers == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'بانتظار تصحيح (لم يجب)',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Case 4: Has pending manual grading
    if (manualPending > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'بانتظار تصحيح ($manualPending)',
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Case 5: Server says no pending and has answers — auto-graded (MCQ only exam)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'تم التصحيح ✓',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
