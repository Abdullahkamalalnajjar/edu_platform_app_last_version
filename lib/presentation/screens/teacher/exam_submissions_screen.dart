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

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
    _fetchNonSubmittedStats();
    _searchController.addListener(_onSearchChanged);
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

    // Apply pending filter
    if (_filterPendingOnly) {
      baseList = baseList.where((s) => s.pendingGradingAnswers > 0).toList();
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
    } else {
      setState(() {
        _error = response.message;
        _isLoading = false;
      });
    }
  }

  /// Silent refresh - updates data without showing loading indicator
  /// Used when returning from exam screen to preserve scroll position
  Future<void> _refreshSubmissionsSilently() async {
    final response = widget.examId != null
        ? await _courseService.getExamSubmissionsByExamId(widget.examId!)
        : await _courseService.getExamSubmissions(widget.lectureId);
    if (mounted && response.succeeded) {
      setState(() {
        _submissions = response.data ?? [];
        _applySearch();
      });
    }
    // Also refresh non-submitted stats
    _fetchNonSubmittedStats();
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

  Widget _buildSummaryCards() {
    final submittedCount =
        _nonSubmittedResponse?.submittedCount ?? _submissions.length;
    final totalEnrolled =
        _nonSubmittedResponse?.totalEnrolledStudents ?? _submissions.length;
    final nonSubmitted = _nonSubmittedResponse?.nonSubmittedCount ?? 0;
    final pendingCount =
        _submissions.where((s) => s.pendingGradingAnswers > 0).length;

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          ).then((_) => _refreshSubmissionsSilently());
        },
      ),
    );
  }
}
