import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_colors.dart';

import '../../../../data/models/api_response.dart';
import '../../../../data/models/course_models.dart';
import '../../../../data/services/teacher_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../video_player_screen.dart';
import '../../teacher/add_exam_questions_screen.dart';
import '../../student/student_exam_screen.dart';
import '../../teacher/exam_submissions_screen.dart';
import '../pdf_viewer_screen.dart';
import '../../../../data/services/course_service.dart';
import '../../../../data/services/subscription_service.dart';
import '../../../../data/services/token_service.dart';
import '../../../widgets/dialogs/add_deadline_exception_dialog.dart';
import '../../../../data/services/settings_service.dart';
import 'widgets/student_score_card.dart';


class CourseDetailsScreen extends StatefulWidget {
  final Course course;
  final bool isTeacher;
  final int? initialLectureId;
  final int? initialMaterialId;

  const CourseDetailsScreen({
    super.key,
    required this.course,
    this.isTeacher = false,
    this.initialLectureId,
    this.initialMaterialId,
  });

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _teacherService = TeacherService();
  final _courseService = CourseService();
  final _subscriptionService = SubscriptionService();
  final _tokenService = TokenService();
  List<Lecture> _lectures = [];
  Map<int, List<Exam>> _lectureExams = {}; // lectureId -> List of Exams
  late AnimationController _backgroundController;
  bool _hasApprovedSubscription = false;
  bool _isAssistant = false; // Track if user is assistant
  StudentCourseScore? _studentScore; // Track student total score

  @override
  void initState() {
    super.initState();
    _lectures = widget.isTeacher
        ? List.from(widget.course.lectures)
        : widget.course.lectures.where((l) => l.isVisible).toList();
    _lectures.sort((a, b) => a.index.compareTo(b.index));
    // Sort materials inside each lecture
    for (var lecture in _lectures) {
      lecture.materials.sort((a, b) => a.index.compareTo(b.index));
    }
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Log the course data received
    print('=== CourseDetailsScreen initState ===');
    print('Course ID: ${widget.course.id}');
    // ... (logs skipped for brevity in replace, but keep them if possible or just proceed) ...
    // To keep it simple, I am replacing the block but I should keep existing logs if I want to be precise, or just replace the variable decl and init

    _checkUserRole();

    if (widget.isTeacher) {
      _fetchExams();
    } else {
      _checkSubscriptionStatus();
      _fetchExams(); // Also fetch for students
      _fetchStudentScore();
    }

    // Auto-open material if ID is provided
    if (widget.initialMaterialId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndOpenInitialMaterial();
      });
    }
    // If initially empty (e.g. partial object from notification) OR we are looking for a specific lecture that might be missing
    // Force refresh if lectures are empty to ensure we have content to show
    if (_lectures.isEmpty ||
        (widget.initialLectureId != null &&
            !_lectures.any((l) => l.id == widget.initialLectureId))) {
      print(
        'Initial lectures empty or target lecture ${widget.initialLectureId} missing - refreshing course...',
      );
      _refreshCourse();
    }

    // Execute config check when entering the screen as requested
    _updateConfig();
  }

  Future<void> _updateConfig() async {
    final settingsService = SettingsService();
    final response = await settingsService.getIconPricerEnabled();
    if (mounted && response.succeeded && response.data != null) {
      setState(() {
        AppConstants.data = response.data!;
      });
      print(
        'Updated AppConstants.data to: ${AppConstants.data} in _updateConfig',
      );
    }
  }

  Future<void> _refreshCourse() async {
    ApiResponse<Course> response = ApiResponse(
      statusCode: 0,
      succeeded: false,
      message: '',
    );

    // Unified refresh strategy:
    // 1. Try to fetch from Teacher Courses List (often contains comprehensive data including hidden lectures for teachers)
    // 2. If that fails or returns empty lectures, fallback to getCourseById (standard detail endpoint)

    final teacherId = widget.course.teacherId;
    bool foundInList = false;

    if (teacherId > 0) {
      print(
        'refreshCourse: Attempting to fetch from teacher list (TeacherId: $teacherId)',
      );
      // We use _teacherService for mapped Course objects which is cleaner
      final listResponse = await _teacherService.getTeacherCourses(teacherId);

      if (listResponse.succeeded && listResponse.data != null) {
        try {
          final foundCourse = listResponse.data!.firstWhere(
            (c) => c.id == widget.course.id,
          );

          // CRITICAL CHECK: Only use this if it actually has lectures!
          if (foundCourse.lectures.isNotEmpty) {
            response = ApiResponse(
              succeeded: true,
              data: foundCourse,
              statusCode: 200,
              message: 'Refreshed from list',
            );
            foundInList = true;
            print(
              '✅ Found course in teacher list with ${foundCourse.lectures.length} lectures',
            );
          } else {
            print(
              '⚠️ Found course in list but it has 0 lectures. Ignoring list result.',
            );
          }
        } catch (_) {
          print('⚠️ Course not found in teacher list');
        }
      }
    }

    if (!foundInList) {
      print(
        'refreshCourse: Falling back to getCourseById (ID: ${widget.course.id})',
      );
      response = await _courseService.getCourseById(widget.course.id);
    }

    if (mounted && response.succeeded && response.data != null) {
      setState(() {
        final allLectures = response.data!.lectures;

        if (_isAssistant || widget.isTeacher) {
          _lectures = List.from(allLectures);
        } else {
          // For students, assume strict filtering.
          // If the API returns hidden lectures (e.g. from Teacher endpoint), we filter them out.
          _lectures = allLectures.where((l) => l.isVisible).toList();
        }
        _lectures.sort((a, b) => a.index.compareTo(b.index));
        // Sort materials inside each lecture
        for (var lecture in _lectures) {
          lecture.materials.sort((a, b) => a.index.compareTo(b.index));
        }
      });
      _fetchExams();
    }
  }

  void _checkAndOpenInitialMaterial() {
    print('Checking for initial material ID: ${widget.initialMaterialId}');
    for (var lecture in _lectures) {
      try {
        final material = lecture.materials.firstWhere(
          (m) => m.id == widget.initialMaterialId,
        );
        print('Found material: ${material.title}, opening...');
        _openMaterial(material);
        break; // Found and opened, stop searching
      } catch (e) {
        // Material not found in this lecture, continue
      }
    }
  }

  Future<void> _fetchStudentScore() async {
    final studentId = await _tokenService.getUserId();
    if (studentId == null) return;

    final response = await _courseService.getStudentCourseScore(
      courseId: widget.course.id,
      studentId: studentId,
    );

    if (mounted && response.succeeded && response.data != null) {
      setState(() {
        _studentScore = response.data;
      });
    }
  }

  Future<void> _checkUserRole() async {
    final role = await _tokenService.getRole();
    if (mounted) {
      setState(() {
        _isAssistant = role == 'Assistant';
        // If the user is a Teacher or Admin or Assistant, they should see all lectures
        // regardless of the widget.isTeacher flag (which might be false if coming from notifications)
        if (role == 'Teacher' || role == 'Admin' || role == 'Assistant') {
          _lectures = List.from(widget.course.lectures);
          _lectures.sort((a, b) => a.index.compareTo(b.index));
          for (var lecture in _lectures) {
            lecture.materials.sort((a, b) => a.index.compareTo(b.index));
          }
        }
      });
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final studentId = await _tokenService.getUserId();
    if (studentId == null) return;

    print('=== Checking Subscription Status ===');
    print('StudentId: $studentId, CourseId: ${widget.course.id}');

    final response = await _subscriptionService.checkStudentSubscriptionStatus(
      studentId: studentId,
      courseId: widget.course.id,
    );

    print(
      'Subscription Response: succeeded=${response.succeeded}, data=${response.data}, message=${response.message}',
    );
    print('====================================');

    if (mounted && response.succeeded && response.data != null) {
      setState(() {
        _hasApprovedSubscription = response.data!;
      });
    }
  }

  Future<void> _fetchExams() async {
    print('=== Fetching Exams for ${_lectures.length} lectures ===');
    for (var lecture in _lectures) {
      print('Fetching exam for lecture ${lecture.id}: ${lecture.title}');
      if (widget.isTeacher) {
        final response = await _teacherService.getExamByLecture(lecture.id);
        print(
          'Teacher response for lecture ${lecture.id}: succeeded=${response.succeeded}, hasData=${response.data != null}',
        );
        if (response.succeeded &&
            response.data != null &&
            response.data!.isNotEmpty) {
          print(
            'Setting ${response.data!.length} exams for lecture ${lecture.id}',
          );
          setState(() {
            _lectureExams[lecture.id] = response.data!;
          });
        } else {
          print('No exam found for lecture ${lecture.id}: ${response.message}');
        }
      } else {
        final response = await _courseService.getExamByLectureId(lecture.id);
        print(
          'Student response for lecture ${lecture.id}: succeeded=${response.succeeded}, hasData=${response.data != null}',
        );
        if (response.succeeded &&
            response.data != null &&
            response.data!.isNotEmpty) {
          setState(() {
            _lectureExams[lecture.id] = response.data!;
          });
        }
      }
    }
    print(
      '=== Exam fetching complete. Total exams: ${_lectureExams.length} ===',
    );
    print('Lecture exams map: ${_lectureExams.keys.toList()}');
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  String _formatDeadline(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.day.toString().padLeft(2, '0')} - '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
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
          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [_buildSliverAppBar(innerBoxIsScrolled)];
              },
              body: RefreshIndicator(
                onRefresh: _refreshCourse,
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              onPressed: _showAddLectureDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: Text(
                'إضافة محاضرة',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(bool innerBoxIsScrolled) {
    final size = MediaQuery.of(context).size;
    final double headerHeight =
        size.width > 700 ? math.min(size.height * 0.28, 300.0) : 180.0;

    return SliverAppBar(
      expandedHeight: headerHeight,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: Theme.of(context).textTheme.bodyLarge?.color,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        if (widget.isTeacher && _lectures.length > 1)
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: IconButton(
              icon: Icon(Icons.swap_vert_rounded,
                  size: 20, color: AppColors.primary),
              tooltip: 'ترتيب المحاضرات',
              onPressed: _showReorderLecturesSheet,
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        title: innerBoxIsScrolled
            ? Text(
                widget.course.title,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (widget.course.courseImageUrl != null &&
                widget.course.courseImageUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  widget.course.courseImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),

            // Gradient Background/Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: (widget.course.courseImageUrl != null &&
                          widget.course.courseImageUrl!.isNotEmpty)
                      ? [
                          Colors.black.withOpacity(0.3),
                          Theme.of(
                            context,
                          ).scaffoldBackgroundColor.withOpacity(0.8),
                          Theme.of(context).scaffoldBackgroundColor,
                        ]
                      : [
                          Theme.of(context).primaryColor.withOpacity(0.15),
                          Theme.of(
                            context,
                          ).scaffoldBackgroundColor.withOpacity(0.8),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                ),
              ),
            ),

            // Decorative Big Circle
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                ),
              ),
            ),

            // Large Title in Background
            Positioned(
              bottom: 30,
              left: 24,
              right: 24,
              child: FadeInUp(
                duration: const Duration(milliseconds: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.course.gradeYear > 0 ||
                        widget.course.educationStageName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school_rounded,
                              size: 14,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.course.educationStageName ??
                                  'Grade ${widget.course.gradeYear}',
                              style: GoogleFonts.inter(
                                color: Theme.of(context).primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.course.gradeYear > 0 ||
                        widget.course.educationStageName != null)
                      const SizedBox(height: 12),
                    Text(
                      widget.course.title,
                      style: GoogleFonts.outfit(
                        fontSize: 24, // Reduced from 32
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).textTheme.displaySmall?.color,
                        height: 1.1,
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                    // Price Display
                    if (AppConstants.data && widget.course.price > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (widget.course.discountedPrice > 0 &&
                              widget.course.discountedPrice <
                                  widget.course.price) ...[
                            Text(
                              '${widget.course.discountedPrice.toStringAsFixed(0)} ج.م',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.course.price.toStringAsFixed(0)} ج.م',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ] else
                            Text(
                              '${widget.course.price.toStringAsFixed(0)} ج.م',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_lectures.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books_rounded,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد محاضرات متاحة بعد',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _refreshCourse,
                  icon: Icon(
                    Icons.refresh,
                    color: Theme.of(context).primaryColor,
                  ),
                  label: const Text('تحديث'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 900;
        final horizontalPadding = isWideScreen ? 48.0 : 16.0;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            if (!widget.isTeacher && _studentScore != null)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverToBoxAdapter(
                  child: StudentScoreCard(studentScore: _studentScore!),
                ),
              ),
            // Section header
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 12, horizontalPadding, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'المحاضرات',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_lectures.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                80,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildLectureCard(_lectures[index], index),
                  ),
                  childCount: _lectures.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLectureCard(Lecture lecture, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).primaryColor;
    final exams = _lectureExams[lecture.id] ?? [];
    final isTeacherOrAssistant = widget.isTeacher || _isAssistant;

    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: 50 * (index % 8)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover Image ─────────────────────────────────
              if (lecture.coverImageUrl != null &&
                  lecture.coverImageUrl!.isNotEmpty)
                Image.network(
                  lecture.coverImageUrl!,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 140,
                      color: accent.withOpacity(0.05),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                ),
              // ── ExpansionTile ────────────────────────────────
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
              tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              childrenPadding: EdgeInsets.zero,
              collapsedBackgroundColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              collapsedShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              title: Text(
                lecture.title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${lecture.materials.length} مادة',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(color: accent.withOpacity(0.6), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${exams.length} اختبار',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                    if (!lecture.isVisible) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'مخفية',
                          style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Teacher quick actions in trailing (3-dot menu)
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTeacherOrAssistant && !_isAssistant)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 22,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showEditLectureDialog(lecture);
                            break;
                          case 'toggle':
                            _toggleLectureVisibility(lecture,
                                targetVisibility: !lecture.isVisible);
                            break;
                          case 'delete':
                            _deleteLecture(lecture.id);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(children: [
                            Icon(
                              lecture.isVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(lecture.isVisible ? 'إخفاء' : 'إظهار',
                                style: GoogleFonts.inter()),
                          ]),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded,
                                size: 18,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color),
                            const SizedBox(width: 8),
                            Text('تعديل', style: GoogleFonts.inter()),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            const Icon(Icons.delete_rounded,
                                size: 18, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text('حذف',
                                style:
                                    GoogleFonts.inter(color: AppColors.error)),
                          ]),
                        ),
                      ],
                    ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.5),
                    size: 20,
                  ),
                ],
              ),
              children: [
                // ── Separator ──────────────────────────────
                Container(height: 1, color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),

                // ── Materials Section ───────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'المواد',
                        style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (lecture.materials.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${lecture.materials.length}',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: accent),
                          ),
                        ),
                    ],
                  ),
                ),
                if (lecture.materials.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'لم يتم إضافة مواد بعد',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...lecture.materials.map((m) => _buildMaterialItem(m)),

                // ── Teacher Material Actions ────────────────
                if (widget.isTeacher) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'إضافة مادة',
                            icon: Icons.add_circle_outline_rounded,
                            color: AppColors.success,
                            onTap: () => _showAddMaterialDialog(lecture, index),
                          ),
                        ),
                        if (lecture.materials.length > 1) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              label: 'ترتيب',
                              icon: Icons.reorder_rounded,
                              color: Colors.blue,
                              onTap: () => _showReorderMaterialsSheet(lecture),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // ── Exams Section ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Row(
                    children: [
                      Icon(Icons.quiz_rounded, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'الاختبارات',
                        style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (exams.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${exams.length}',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ),
                    ],
                  ),
                ),
                if (exams.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Text(
                        'لا توجد اختبارات',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...exams.map((e) => _buildExamItem(e)),

                // ── Teacher: Create Exam Button ─────────────
                if (widget.isTeacher) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                    child: _buildActionButton(
                      label: 'إنشاء اختبار جديد',
                      icon: Icons.quiz_rounded,
                      color: Colors.orange,
                      onTap: () => _showCreateExamDialog(lecture),
                    ),
                  ),
                ] else
                  const SizedBox(height: 12),

                // ── Bottom accent line ───────────────────────
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.15)],
                    ),
                  ),
                ),
              ],
            ),
          ),   // close Theme
          ],   // close Column children
          ),   // close Column
        ),     // close ClipRRect
      ),       // close Container
    );         // close FadeInUp
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use brighter variant of color in dark mode for better visibility
    final displayColor = isDark ? Color.lerp(color, Colors.white, 0.3)! : color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: displayColor.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: displayColor.withOpacity(isDark ? 0.5 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: displayColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(color: displayColor, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _showEditLectureDialog(Lecture lecture) async {
    final titleController = TextEditingController(text: lecture.title);
    String? selectedCoverImagePath;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تعديل المحاضرة',
            style: GoogleFonts.outfit(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'عنوان المحاضرة',
                    labelStyle:
                        const TextStyle(color: AppColors.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Cover image preview / picker
                Text(
                  'صورة الغلاف (اختياري)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // Show existing cover image
                if (lecture.coverImageUrl != null &&
                    lecture.coverImageUrl!.isNotEmpty &&
                    selectedCoverImagePath == null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      lecture.coverImageUrl!,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                if (selectedCoverImagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildFileImage(selectedCoverImagePath!),
                  ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                    );
                    if (result != null && result.files.single.path != null) {
                      setDialogState(() {
                        selectedCoverImagePath = result.files.single.path;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image_outlined,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedCoverImagePath != null
                                ? selectedCoverImagePath!
                                    .split('/')
                                    .last
                                    .split('\\')
                                    .last
                                : 'اختر صورة غلاف',
                            style: GoogleFonts.inter(
                              color: selectedCoverImagePath != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedCoverImagePath != null)
                          GestureDetector(
                            onTap: () => setDialogState(
                                () => selectedCoverImagePath = null),
                            child: const Icon(Icons.close,
                                size: 16,
                                color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  final request = LectureRequest(
                    title: titleController.text,
                    courseId: widget.course.id,
                  );
                  final response = await _teacherService.updateLecture(
                    request,
                    lecture.id,
                    coverImagePath: selectedCoverImagePath,
                  );

                  if (response.succeeded) {
                    await _refreshCourse();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('تم تحديث المحاضرة بنجاح')),
                      );
                  } else {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(response.message),
                          backgroundColor: AppColors.error,
                        ),
                      );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLecture(int lectureId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف المحاضرة'),
        content: const Text(
          'هل أنت متأكد أنك تريد حذف هذه المحاضرة؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _teacherService.deleteLecture(lectureId);
      if (response.succeeded) {
        setState(() {
          _lectures.removeWhere((l) => l.id == lectureId);
        });
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حذف المحاضرة')));
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.error,
            ),
          );
      }
    }
  }

  Widget _buildMaterialItem(CourseMaterial material) {
    Widget leadingIcon;
    Color iconColor;
    String typeLabel;

    // Helper to get filename
    String getFileName(String url) {
      if (url.isEmpty) return 'File';
      try {
        return Uri.parse(url).pathSegments.last;
      } catch (e) {
        return url.split('/').last;
      }
    }

    switch (material.type) {
      case 'Video':
        iconColor = const Color(0xFFFF5252);
        final videoId = YoutubePlayer.convertUrlToId(material.fileUrl);
        // Use hqdefault for better quality than default, but 0.jpg is also an option.
        // standard format: https://img.youtube.com/vi/<insert-youtube-video-id-here>/hqdefault.jpg
        final thumbnailUrl = videoId != null
            ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg'
            : '';

        leadingIcon = Container(
          width: 80, // Wider for 16:9 thumbnail ratio
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFF2A1C1C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            image: thumbnailUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(thumbnailUrl),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      // Fallback is handled by the child below if image fails to render?
                      // Actually DecorationImage doesn't easily support fallback widget.
                      // We will rely on effective thumbnail urls.
                    },
                  )
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dark overlay for better text/icon visibility if image is bright
              if (thumbnailUrl.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              // Play Icon Overlay
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        );
        typeLabel = 'محاضرة فيديو';
        break;
      case 'Pdf':
        iconColor = const Color(0xFFE57373);
        leadingIcon = Container(
          padding: const EdgeInsets.all(6), // Reduced from 8
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.picture_as_pdf_rounded,
            color: iconColor,
            size: 20,
          ), // Reduced from 24
        );
        typeLabel = getFileName(material.fileUrl).replaceAll('%20', ' ');
        break;
      case 'Homework':
        iconColor = const Color(0xFF64B5F6);
        leadingIcon = Container(
          padding: const EdgeInsets.all(6), // Reduced from 8
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.assignment_rounded,
            color: iconColor,
            size: 20,
          ), // Reduced from 24
        );
        typeLabel = getFileName(material.fileUrl).replaceAll('%20', ' ');
        break;
      default:
        iconColor = AppColors.textSecondary;
        leadingIcon = Container(
          padding: const EdgeInsets.all(6), // Reduced from 8
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.insert_drive_file_rounded,
            color: iconColor,
            size: 20, // Reduced from 24
          ),
        );
        typeLabel = getFileName(material.fileUrl).replaceAll('%20', ' ');
    }

    return GestureDetector(
      onTap: (widget.isTeacher || material.isFree || _hasApprovedSubscription)
          ? () => _openMaterial(material)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ), // Reduced from 20, 6
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ), // Reduced from 12, 10
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover Image (if available) ────────────────────────
            if (material.coverImageUrl != null &&
                material.coverImageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  material.coverImageUrl!,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 160,
                      color: AppColors.background.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Title Row - On its own
            Row(
              children: [
                Expanded(
                  child: Text(
                    material.title ?? typeLabel,
                    style: GoogleFonts.inter(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13, // Reduced from 15
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Delete Button for Teachers moved here or kept below?
                // Let's keep actions on the second row for a cleaner look or top right
                if (widget.isTeacher && !_isAssistant) ...[
                  const SizedBox(width: 8),
                  // Edit Button
                  GestureDetector(
                    onTap: () => _showEditMaterialDialog(material),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deleteMaterial(material.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Leading Icon/Thumbnail
                leadingIcon,
                const SizedBox(width: 12),

                // Subtitle
                if (widget.isTeacher ||
                    material.isFree ||
                    _hasApprovedSubscription)
                  Text(
                    material.type == 'Video' ? 'اضغط للمشاهدة' : 'اضغط للفتح',
                    style: GoogleFonts.inter(
                      fontSize: 11, // Reduced from 12
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                const Spacer(),

                // Trailing - Free/Paid Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: material.isFree
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: material.isFree
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        material.isFree
                            ? Icons.check_circle_rounded
                            : Icons.lock_rounded,
                        color: material.isFree
                            ? AppColors.success
                            : AppColors.error,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        material.isFree ? 'مجاني' : 'مدفوع',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: material.isFree
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamItem(Exam exam) {
    final isAssignment = exam.type == 'Assignment';
    final themeColor = isAssignment ? Colors.blue : Colors.orange;
    final icon = isAssignment ? Icons.assignment_rounded : Icons.quiz_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Info Section
          InkWell(
            onTap: () async {
              if (!widget.isTeacher &&
                  !_hasApprovedSubscription &&
                  !exam.isFree) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يجب الاشتراك في الكورس لدخول الامتحان'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              // For students: Check exam access (deadline + exceptions)
              if (!widget.isTeacher) {
                final accessResponse = await _courseService.checkExamAccess(
                  examId: exam.id,
                );

                if (!accessResponse.succeeded || accessResponse.data == null) {
                  // API error - still allow access (student_exam_screen will handle it)
                  print('⚠️ Failed to check exam access, allowing anyway');
                } else {
                  final access = accessResponse.data!;

                  // Show appropriate message based on status
                  if (access.hasException && mounted) {
                    // Has exception - show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '✅ لديك استثناء للموعد النهائي',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (access.extendedDeadline != null)
                              Text(
                                'الموعد الجديد: ${_formatDeadline(access.extendedDeadline!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } else if (!access.canAccess && mounted) {
                    // No access but allow anyway - show warning
                    // (student might have finished exam and wants to see results)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '⚠️ الموعد النهائي للامتحان قد انتهى',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (access.deadline != null)
                              Text(
                                'انتهى في: ${_formatDeadline(access.deadline!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        backgroundColor: AppColors.warning,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }

              // Open exam (always allow - student_exam_screen will handle restrictions)
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentExamScreen(
                      lectureId: exam.lectureId,
                      examId: exam.id,
                      lectureTitle: exam.lectureName ?? 'Lecture Exam',
                      isTeacher: widget.isTeacher,
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom:
                  widget.isTeacher ? Radius.zero : const Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12), // Reduced from 20
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10), // Reduced from 14
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [themeColor.shade400, themeColor.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // Reduced from 16
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 20,
                    ), // Reduced from 28
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.title,
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15, // Reduced from 18
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.format_list_numbered_rounded,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${exam.questions.length} أسئلة',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.timer_rounded,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${exam.durationInMinutes} دقيقة',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isTeacher)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_hasApprovedSubscription || exam.isFree)
                            ? AppColors.surfaceLight
                            : AppColors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        (_hasApprovedSubscription || exam.isFree)
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.lock_rounded,
                        color: (_hasApprovedSubscription || exam.isFree)
                            ? AppColors.textPrimary
                            : AppColors.error,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Teacher Actions Section
          if (widget.isTeacher || _isAssistant) ...[
            Container(height: 1, color: AppColors.glassBorder.withOpacity(0.5)),
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildExamActionButton(
                      icon: Icons.people_alt_rounded,
                      label: 'تسليمات',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExamSubmissionsScreen(
                              lectureId: exam.lectureId,
                              lectureTitle:
                                  exam.lectureName ?? 'اختبار المحاضرة',
                              examId: exam.id,
                              courseId: widget.course.id,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildExamActionButton(
                      icon: Icons.visibility_rounded,
                      label: 'معاينة',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentExamScreen(
                              lectureId: exam.lectureId,
                              examId: exam.id,
                              lectureTitle:
                                  exam.lectureName ?? 'معاينة الاختبار',
                              isTeacher: true,
                            ),
                          ),
                        ).then((_) => _fetchExams());
                      },
                    ),
                    _buildExamActionButton(
                      icon: exam.isVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      label: exam.isVisible ? 'إخفاء' : 'إظهار',
                      color: exam.isVisible
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      onTap: () => _toggleExamVisibility(exam),
                    ),
                    _buildExamActionButton(
                      icon: Icons.more_time_rounded,
                      label: 'استثناء',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AddDeadlineExceptionDialog(
                            courseId: widget.course.id,
                            examId: exam.id,
                            teacherId: widget.course.teacherId,
                          ),
                        );
                      },
                    ),
                    _buildExamActionButton(
                      icon: Icons.edit_note_rounded,
                      label: 'الأسئلة',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddExamQuestionsScreen(
                              examId: exam.id,
                              existingExam: exam,
                            ),
                          ),
                        ).then((_) => _fetchExams());
                      },
                    ),
                    _buildExamActionButton(
                      icon: Icons.settings_rounded,
                      label: 'إعدادات',
                      onTap: () => _showEditExamDialog(exam),
                    ),
                    // Hide delete button from assistants
                    if (!_isAssistant)
                      _buildExamActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'حذف',
                        color: AppColors.error,
                        onTap: () => _deleteExam(exam.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExamActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.orange,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ), // Reduced padding
        child: Column(
          children: [
            Icon(icon, color: color, size: 20), // Reduced icon size
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1, // Prevent wrapping
              overflow: TextOverflow.fade, // Handle overflow gracefully
              softWrap: false,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11, // Reduced font size
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExam(int examId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف الاختبار'),
        content: const Text(
          'هل أنت متأكد أنك تريد حذف هذا الاختبار؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _teacherService.deleteExam(examId);
      if (response.succeeded) {
        setState(() {
          // Remove exam from local state - iterate through lists and remove matching exam
          for (var examList in _lectureExams.values) {
            examList.removeWhere((exam) => exam.id == examId);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الاختبار بنجاح')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleExamVisibility(Exam exam) async {
    final newVisibility = !exam.isVisible;
    final response = await _teacherService.changeExamVisibility(
      examId: exam.id,
      isVisible: newVisibility,
    );

    if (response.succeeded) {
      setState(() {
        for (var lectureId in _lectureExams.keys) {
          final exams = _lectureExams[lectureId]!;
          final index = exams.indexWhere((e) => e.id == exam.id);
          if (index != -1) {
            exams[index] = Exam(
              id: exam.id,
              title: exam.title,
              lectureId: exam.lectureId,
              lectureName: exam.lectureName,
              deadline: exam.deadline,
              durationInMinutes: exam.durationInMinutes,
              type: exam.type,
              isRandomized: exam.isRandomized,
              questions: exam.questions,
              isVisible: newVisibility,
            );
            break;
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newVisibility
                  ? 'تم إظهار الاختبار للطلاب'
                  : 'تم إخفاء الاختبار عن الطلاب',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleLectureVisibility(
    Lecture lecture, {
    bool? targetVisibility,
  }) async {
    final newVisibility = targetVisibility ?? !lecture.isVisible;
    final response = await _teacherService.changeLectureVisibility(
      lectureId: lecture.id,
      isVisible: newVisibility,
    );

    if (response.succeeded) {
      setState(() {
        final index = _lectures.indexWhere((l) => l.id == lecture.id);
        if (index != -1) {
          _lectures[index] = Lecture(
            id: lecture.id,
            title: lecture.title,
            courseId: lecture.courseId,
            materials: lecture.materials,
            isVisible: newVisibility,
            index: lecture.index,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newVisibility ? 'تم إظهار المحاضرة' : 'تم إخفاء المحاضرة',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteMaterial(int materialId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف المادة'),
        content: const Text(
          'هل أنت متأكد أنك تريد حذف هذه المادة؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _teacherService.deleteMaterial(materialId);
      if (response.succeeded) {
        setState(() {
          for (var lecture in _lectures) {
            lecture.materials.removeWhere((m) => m.id == materialId);
          }
        });
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حذف المادة')));
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.error,
            ),
          );
      }
    }
  }

  // --- Logic Methods (Kept As Is) ---

  /// Builds an Image widget from a local file path (dart:io)
  Widget _buildFileImage(String path, {double height = 120}) {
    return Image.file(
      File(path),
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox(),
    );
  }

  Future<void> _showAddLectureDialog() async {
    final titleController = TextEditingController();
    String? selectedCoverImagePath;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sbContext, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle bar ──
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFFE53935)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.library_books_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إضافة محاضرة جديدة',
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            widget.course.title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),

                // ── Content ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title Input ──
                        Text(
                          'عنوان المحاضرة *',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: titleController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'أدخل عنوان المحاضرة',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                            prefixIcon: Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Cover Image ──
                        Text(
                          'صورة الغلاف (اختياري)',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Preview
                        if (selectedCoverImagePath != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: _buildFileImage(selectedCoverImagePath!, height: 140),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setSheetState(() => selectedCoverImagePath = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Picker
                        GestureDetector(
                          onTap: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                            );
                            if (result != null && result.files.single.path != null) {
                              setSheetState(() {
                                selectedCoverImagePath = result.files.single.path;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedCoverImagePath != null
                                  ? AppColors.success.withOpacity(isDark ? 0.12 : 0.06)
                                  : isDark
                                      ? Colors.white.withOpacity(0.04)
                                      : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selectedCoverImagePath != null
                                    ? AppColors.success.withOpacity(0.4)
                                    : isDark
                                        ? Colors.white12
                                        : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selectedCoverImagePath != null
                                      ? Icons.image_rounded
                                      : Icons.add_photo_alternate_outlined,
                                  color: selectedCoverImagePath != null
                                      ? AppColors.success
                                      : isDark
                                          ? Colors.white.withOpacity(0.4)
                                          : Colors.grey.shade500,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedCoverImagePath != null
                                        ? selectedCoverImagePath!
                                            .split('/').last
                                            .split('\\').last
                                        : 'اختر صورة غلاف للمحاضرة',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selectedCoverImagePath != null
                                          ? AppColors.success
                                          : isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Info Note ──
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(isDark ? 0.1 : 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                size: 18, color: Colors.amber.shade700),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'المحاضرة ستكون مخفية بشكل افتراضي حتى تقوم بإظهارها',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Action Buttons ──
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'إلغاء',
                                  style: GoogleFonts.tajawal(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (titleController.text.isNotEmpty) {
                                    Navigator.pop(sheetContext);
                                    final request = LectureRequest(
                                      title: titleController.text,
                                      courseId: widget.course.id,
                                    );
                                    final response = await _teacherService.createLecture(
                                      request,
                                      coverImagePath: selectedCoverImagePath,
                                    );
                                    if (response.succeeded && response.data != null) {
                                      await _teacherService.changeLectureVisibility(
                                        lectureId: response.data!,
                                        isVisible: false,
                                      );
                                      await _refreshCourse();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('تم إضافة المحاضرة بنجاح (مخفية)'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('يرجى إدخال عنوان المحاضرة'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_rounded, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      'إضافة محاضرة',
                                      style: GoogleFonts.tajawal(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddMaterialDialog(Lecture lecture, int lectureIndex) async {
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    final allTypes = ['Video', 'Pdf', 'Image', 'Homework'];
    final materialTypes = _isAssistant ? ['Video', 'Pdf', 'Image'] : allTypes;

    String selectedType = 'Video';
    bool isFree = false;
    PlatformFile? selectedFile;
    String? coverImagePath;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sbContext, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle bar ──
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إضافة مادة جديدة',
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            lecture.title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),

                // ── Content ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title Input ──
                        Text(
                          'عنوان المادة *',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: titleController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'أدخل عنوان المادة',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                            prefixIcon: Icon(
                              Icons.title_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.success,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Material Type Chips ──
                        Text(
                          'نوع المادة',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: materialTypes.map((type) {
                            final isSelected = selectedType == type;
                            final chipColor = _getMaterialChipColor(type);
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  selectedType = type;
                                  selectedFile = null;
                                  urlController.clear();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? chipColor.withOpacity(0.15)
                                      : isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? chipColor
                                        : isDark
                                            ? Colors.white12
                                            : Colors.grey.shade200,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getMaterialIcon(type),
                                      size: 18,
                                      color: isSelected
                                          ? chipColor
                                          : isDark
                                              ? Colors.white.withOpacity(0.4)
                                              : Colors.black38,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getMaterialLabel(type),
                                      style: GoogleFonts.tajawal(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? chipColor
                                            : isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // ── Video URL or File Picker ──
                        if (selectedType == 'Video') ...[
                          Text(
                            'رابط الفيديو *',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: urlController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'https://youtu.be/...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              prefixIcon: const Icon(
                                Icons.play_circle_rounded,
                                color: Color(0xFFFF5252),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF5252),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // File Picker
                          GestureDetector(
                            onTap: () async {
                              FileType fileType = FileType.any;
                              List<String>? allowedExtensions;

                              if (selectedType == 'Pdf') {
                                fileType = FileType.custom;
                                allowedExtensions = ['pdf'];
                              } else if (selectedType == 'Image') {
                                fileType = FileType.image;
                              } else if (selectedType == 'Homework') {
                                fileType = FileType.custom;
                                allowedExtensions = [
                                  'pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png',
                                ];
                              }

                              final result = await FilePicker.platform.pickFiles(
                                type: fileType,
                                allowedExtensions: allowedExtensions,
                              );

                              if (result != null && result.files.isNotEmpty) {
                                setSheetState(() {
                                  selectedFile = result.files.first;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: selectedFile != null
                                    ? AppColors.success.withOpacity(isDark ? 0.12 : 0.06)
                                    : isDark
                                        ? Colors.white.withOpacity(0.04)
                                        : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedFile != null
                                      ? AppColors.success.withOpacity(0.5)
                                      : isDark
                                          ? Colors.white12
                                          : Colors.grey.shade200,
                                  width: selectedFile != null ? 1.5 : 1,
                                  style: selectedFile != null
                                      ? BorderStyle.solid
                                      : BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    selectedFile != null
                                        ? Icons.check_circle_rounded
                                        : Icons.cloud_upload_rounded,
                                    size: 36,
                                    color: selectedFile != null
                                        ? AppColors.success
                                        : isDark
                                            ? Colors.white30
                                            : Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    selectedFile != null
                                        ? 'تم اختيار الملف'
                                        : 'اضغط لاختيار ملف',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: selectedFile != null
                                          ? AppColors.success
                                          : isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedFile != null
                                        ? selectedFile!.name
                                        : _getFileTypeHint(selectedType),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // ── Cover Image ──
                        GestureDetector(
                          onTap: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setSheetState(() {
                                coverImagePath = result.files.first.path;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: coverImagePath != null
                                  ? AppColors.success.withOpacity(isDark ? 0.12 : 0.06)
                                  : isDark
                                      ? Colors.white.withOpacity(0.04)
                                      : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: coverImagePath != null
                                    ? AppColors.success.withOpacity(0.4)
                                    : isDark
                                        ? Colors.white12
                                        : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  coverImagePath != null
                                      ? Icons.image_rounded
                                      : Icons.add_photo_alternate_outlined,
                                  color: coverImagePath != null
                                      ? AppColors.success
                                      : isDark
                                          ? Colors.white.withOpacity(0.4)
                                          : Colors.grey.shade500,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        coverImagePath != null
                                            ? 'تم اختيار صورة الغلاف'
                                            : 'صورة الغلاف (اختياري)',
                                        style: GoogleFonts.tajawal(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: coverImagePath != null
                                              ? AppColors.success
                                              : isDark
                                                  ? Colors.white54
                                                  : Colors.black45,
                                        ),
                                      ),
                                      if (coverImagePath != null)
                                        Text(
                                          coverImagePath!.split('\\').last.split('/').last,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (coverImagePath != null)
                                  GestureDetector(
                                    onTap: () => setSheetState(() => coverImagePath = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Free Toggle ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (isFree ? AppColors.success : AppColors.error)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isFree ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  color: isFree ? AppColors.success : AppColors.error,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'محتوى مجاني',
                                style: GoogleFonts.tajawal(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: isFree,
                                onChanged: (value) {
                                  setSheetState(() => isFree = value);
                                },
                                activeColor: AppColors.success,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Action Buttons ──
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'إلغاء',
                                  style: GoogleFonts.tajawal(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Validation
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('يرجى إدخال عنوان المادة'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }
                                  if (selectedType == 'Video' && urlController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('يرجى إدخال رابط الفيديو'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }
                                  if (selectedType != 'Video') {
                                    if (selectedFile == null || selectedFile!.path == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('يرجى اختيار ملف صالح'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                      return;
                                    }
                                  }

                                  Navigator.pop(sheetContext);

                                  ApiResponse<int> response;

                                  if (selectedType == 'Video') {
                                    final request = MaterialRequest(
                                      type: selectedType,
                                      lectureId: lecture.id,
                                      videoUrl: urlController.text.trim(),
                                      title: titleController.text.trim(),
                                      isFree: isFree,
                                    );
                                    response = await _teacherService.createMaterial(
                                      request,
                                      coverImagePath: coverImagePath,
                                    );
                                  } else {
                                    response = await _teacherService.createMaterialWithFile(
                                      type: selectedType,
                                      lectureId: lecture.id,
                                      filePath: selectedFile!.path!,
                                      fileName: selectedFile!.name,
                                      title: titleController.text.trim(),
                                      isFree: isFree,
                                      coverImagePath: coverImagePath,
                                    );
                                  }

                                  if (response.succeeded && response.data != null) {
                                    if (mounted) {
                                      setState(() {
                                        final newMaterial = CourseMaterial(
                                          id: response.data!,
                                          type: selectedType,
                                          fileUrl: selectedType == 'Video'
                                              ? urlController.text.trim()
                                              : selectedFile!.path!,
                                          isFree: isFree,
                                          index: lecture.materials.length,
                                          title: titleController.text.trim(),
                                        );

                                        final updatedMaterials = List<CourseMaterial>.from(
                                          lecture.materials,
                                        )..add(newMaterial);
                                        updatedMaterials.sort((a, b) => a.index.compareTo(b.index));

                                        _lectures[lectureIndex] = Lecture(
                                          id: lecture.id,
                                          title: lecture.title,
                                          courseId: lecture.courseId,
                                          materials: updatedMaterials,
                                          isVisible: lecture.isVisible,
                                          index: lecture.index,
                                        );
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تم إضافة ${_getMaterialLabel(selectedType)} بنجاح'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(response.message),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_rounded, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      'إضافة',
                                      style: GoogleFonts.tajawal(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getMaterialLabel(String type) {
    switch (type) {
      case 'Video': return 'فيديو';
      case 'Pdf': return 'PDF';
      case 'Image': return 'صورة';
      case 'Homework': return 'واجب';
      default: return type;
    }
  }

  Color _getMaterialChipColor(String type) {
    switch (type) {
      case 'Video': return const Color(0xFFFF5252);
      case 'Pdf': return const Color(0xFFE57373);
      case 'Image': return Colors.blue;
      case 'Homework': return Colors.orange;
      default: return AppColors.primary;
    }
  }

  Future<void> _showEditMaterialDialog(CourseMaterial material) async {
    final titleController = TextEditingController(text: material.title);
    bool isFree = material.isFree;
    String? coverImagePath;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sbContext, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تعديل المادة',
            style: GoogleFonts.outfit(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    labelText: 'عنوان المادة',
                    labelStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Cover image picker (optional)
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setDialogState(() {
                        coverImagePath = result.files.first.path;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: coverImagePath != null
                          ? AppColors.success.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: coverImagePath != null
                            ? AppColors.success.withOpacity(0.4)
                            : AppColors.textSecondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          coverImagePath != null
                              ? Icons.image_rounded
                              : Icons.add_photo_alternate_outlined,
                          color: coverImagePath != null
                              ? AppColors.success
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                coverImagePath != null
                                    ? 'تم اختيار صورة الغلاف'
                                    : 'صورة الغلاف (اختياري)',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: coverImagePath != null
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (coverImagePath != null)
                                Text(
                                  coverImagePath!
                                      .split('\\')
                                      .last
                                      .split('/')
                                      .last,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (coverImagePath != null)
                          GestureDetector(
                            onTap: () =>
                                setDialogState(() => coverImagePath = null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'محتوى مجاني',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      Switch(
                        value: isFree,
                        onChanged: (value) {
                          setDialogState(() {
                            isFree = value;
                          });
                        },
                        activeColor: AppColors.success,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  
                  // Find lectureId for this material
                  int lectureId = 0;
                  for (var l in _lectures) {
                    if (l.materials.any((m) => m.id == material.id)) {
                      lectureId = l.id;
                      break;
                    }
                  }

                  final response = await _teacherService.editLectureMaterial(
                    id: material.id,
                    title: titleController.text.trim(),
                    type: material.type,
                    fileUrl: material.fileUrl,
                    lectureId: lectureId,
                    isFree: isFree,
                    coverImagePath: coverImagePath,
                  );

                  if (response.succeeded) {
                    setState(() {
                      for (var lecture in _lectures) {
                        final index = lecture.materials.indexWhere(
                          (m) => m.id == material.id,
                        );
                        if (index != -1) {
                          lecture.materials[index] = CourseMaterial(
                            id: material.id,
                            type: material.type,
                            fileUrl: material.fileUrl,
                            title: titleController.text.trim(),
                            isFree: isFree,
                            index: material.index,
                          );
                          break;
                        }
                      }
                    });
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تحديث المادة بنجاح')),
                      );
                  } else {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(response.message),
                          backgroundColor: AppColors.error,
                        ),
                      );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileTypeHint(String type) {
    switch (type) {
      case 'Pdf':
        return 'PDF files only';
      case 'Image':
        return 'JPG, PNG, GIF images';
      case 'Homework':
        return 'PDF, DOC, DOCX, or images';
      default:
        return 'Select a file';
    }
  }

  IconData _getMaterialIcon(String type) {
    switch (type) {
      case 'Video':
        return Icons.play_circle_outline_rounded;
      case 'Pdf':
        return Icons.picture_as_pdf_rounded;
      case 'Image':
        return Icons.image_rounded;
      case 'Homework':
        return Icons.assignment_rounded;
      default:
        return Icons.attach_file_rounded;
    }
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
                        AppColors.meshGold.withOpacity(0.15),
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

  void _openMaterial(CourseMaterial material) async {
    if (material.type == 'Video') {
      _openVideo(material.fileUrl);
    } else {
      bool isUrl = material.fileUrl.startsWith('http');
      bool isPdf = material.fileUrl.toLowerCase().contains('.pdf') ||
          material.type == 'Pdf';

      if (isPdf && isUrl) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              pdfUrl: material.fileUrl,
              title: material.title ?? 'عرض الملف',
            ),
          ),
        );
      } else if (isUrl) {
        await _launchExternalURL(material.fileUrl);
      } else if (isPdf) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              pdfUrl: material.fileUrl,
              title: material.title ?? 'عرض الملف',
              isLocal: true,
            ),
          ),
        );
      } else {
        final result = await OpenFilex.open(material.fileUrl);
        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open file: ${result.message}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
  }

  void _openVideo(String url) {
    // Check if URL is a valid YouTube URL
    final youtubeRegex = RegExp(
      r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.+$',
      caseSensitive: false,
    );

    if (youtubeRegex.hasMatch(url)) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(videoUrl: url),
        ),
      );
    } else {
      _launchExternalURL(url);
    }
  }

  Future<void> _launchExternalURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch video URL')),
        );
      }
    }
  }

  Future<void> _showCreateExamDialog(Lecture lecture) async {
    final titleController = TextEditingController();
    final durationController = TextEditingController();
    // Default deadline: one year from now
    DateTime? selectedDeadline = DateTime(
      DateTime.now().year + 1,
      DateTime.now().month,
      DateTime.now().day,
      23, 59,
    );
    DateTime? selectedPublishedAt;
    int selectedType = 1; // 1 = Exam, 2 = Assignment
    bool isRandomized = true;
    bool isFree = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'إنشاء اختبار جديد',
            style: GoogleFonts.outfit(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    labelText: 'عنوان الاختبار',
                    labelStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Exam Type Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedType,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            "اختبار (Real Exam)",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            "واجب (Assignment)",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedType = val!);
                      },
                    ),
                  ),
                ),
                if (selectedType == 1) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'المدة (بالدقائق)',
                      hintText: 'مثال: 60',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Randomize Questions Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.glassBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'ترتيب عشوائي للأسئلة',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: isRandomized,
                    onChanged: (val) {
                      setDialogState(() => isRandomized = val);
                    },
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                // Is Free Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.glassBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'اختبار مجاني',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: isFree,
                    onChanged: (val) {
                      setDialogState(() => isFree = val);
                    },
                    activeColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: AppColors.surface,
                              onSurface: AppColors.textPrimary,
                            ),
                            dialogBackgroundColor: AppColors.surface,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
                          return child!;
                        },
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDeadline = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.glassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          selectedDeadline != null
                              ? '${selectedDeadline!.toLocal()}'.split('.')[0]
                              : 'اختر موعداً نهائياً (اختياري)',
                          style: TextStyle(
                            color: selectedDeadline != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── publishedAt picker ─────────────────────────────
                const SizedBox(height: 16),
                Text(
                  'تاريخ النشر (اختياري)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedPublishedAt ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedPublishedAt != null
                            ? TimeOfDay.fromDateTime(selectedPublishedAt!)
                            : TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedPublishedAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.glassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedPublishedAt != null
                                ? '${selectedPublishedAt!.toLocal()}'.split('.')[0]
                                : 'اختر تاريخ النشر (اختياري)',
                            style: TextStyle(
                              color: selectedPublishedAt != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (selectedPublishedAt != null)
                          GestureDetector(
                            onTap: () => setDialogState(
                              () => selectedPublishedAt = null,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // ── deadline picker ────────────────────────────────
                const SizedBox(height: 16),
                Text(
                  'الموعد النهائي (اختياري)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDeadline ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
                          return child!;
                        },
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDeadline = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.glassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          selectedDeadline != null
                              ? '${selectedDeadline!.toLocal()}'.split('.')[0]
                              : 'اختر موعداً نهائياً (اختياري)',
                          style: TextStyle(
                            color: selectedDeadline != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                Navigator.pop(dialogContext);

                String? deadlineStr;
                if (selectedDeadline != null) {
                  deadlineStr = selectedDeadline!.toUtc().toIso8601String();
                }
                String? publishedAtStr;
                if (selectedPublishedAt != null) {
                  publishedAtStr =
                      selectedPublishedAt!.toUtc().toIso8601String();
                }

                final request = ExamRequest(
                  title: titleController.text,
                  lectureId: lecture.id,
                  deadline: deadlineStr,
                  durationInMinutes: selectedType == 1
                      ? (int.tryParse(durationController.text) ?? 0)
                      : 0,
                  type: selectedType,
                  isRandomized: isRandomized,
                  isFree: isFree,
                  publishedAt: publishedAtStr,
                );

                // Capture the scaffold messenger before async gap if possible,
                // but since we might navigate, using context with mounted check is standard.
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                final response = await _teacherService.createExam(request);

                if (!mounted) return;

                if (response.succeeded && response.data != null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم إنشاء الاختبار بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  navigator
                      .push(
                        MaterialPageRoute(
                          builder: (context) =>
                              AddExamQuestionsScreen(examId: response.data!),
                        ),
                      )
                      .then((_) => _fetchExams());
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${response.message}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditExamDialog(Exam exam) async {
    final titleController = TextEditingController(text: exam.title);
    final durationController = TextEditingController(
      text: exam.durationInMinutes.toString(),
    );
    DateTime? selectedDeadline = exam.deadline?.toLocal();
    DateTime? selectedPublishedAt = exam.publishedAt?.toLocal();
    int selectedType = (exam.type == 'Assignment') ? 2 : 1;
    bool isRandomized = exam.isRandomized;
    bool isFree = exam.isFree;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'تعديل الاختبار',
            style: GoogleFonts.outfit(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    labelText: 'عنوان الاختبار',
                    labelStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                if (selectedType == 1) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      labelText: 'المدة (بالدقائق)',
                      hintText: 'مثال: 60',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Randomize Questions Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'ترتيب عشوائي للأسئلة',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: isRandomized,
                    onChanged: (val) {
                      setDialogState(() => isRandomized = val);
                    },
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                // Is Free Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'اختبار مجاني',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: isFree,
                    onChanged: (val) {
                      setDialogState(() => isFree = val);
                    },
                    activeColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                // ── publishedAt picker ────────────────────────────────
                Text(
                  'تاريخ النشر (اختياري)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedPublishedAt ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedPublishedAt != null
                            ? TimeOfDay.fromDateTime(selectedPublishedAt!)
                            : TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedPublishedAt = DateTime(
                            date.year, date.month, date.day,
                            time.hour, time.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.glassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedPublishedAt != null
                                ? '${selectedPublishedAt!.toLocal()}'.split('.')[0]
                                : 'اختر تاريخ النشر (اختياري)',
                            style: TextStyle(
                              color: selectedPublishedAt != null
                                  ? Theme.of(context).textTheme.bodyLarge?.color
                                  : Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                        if (selectedPublishedAt != null)
                          GestureDetector(
                            onTap: () => setDialogState(
                              () => selectedPublishedAt = null,
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                // ── deadline picker ────────────────────────────────
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final initialDate = selectedDeadline ?? DateTime.now();
                    final firstDate = initialDate.isBefore(DateTime.now())
                        ? initialDate
                        : DateTime.now();

                    final date = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: AppColors.surface,
                              onSurface: AppColors.textPrimary,
                            ),
                            dialogBackgroundColor: AppColors.surface,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                          selectedDeadline ?? DateTime.now(),
                        ),
                        builder: (context, child) {
                          return child!;
                        },
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDeadline = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.glassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          selectedDeadline != null
                              ? '${selectedDeadline!.toLocal()}'.split('.')[0]
                              : 'Select Deadline (Optional)',
                          style: TextStyle(
                            color: selectedDeadline != null
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                Navigator.pop(dialogContext);

                String? deadlineStr;
                if (selectedDeadline != null) {
                  deadlineStr = selectedDeadline!.toUtc().toIso8601String();
                }
                String? publishedAtStr;
                if (selectedPublishedAt != null) {
                  publishedAtStr =
                      selectedPublishedAt!.toUtc().toIso8601String();
                }

                final request = ExamRequest(
                  title: titleController.text,
                  lectureId: exam.lectureId,
                  deadline: deadlineStr,
                  durationInMinutes: selectedType == 1
                      ? (int.tryParse(durationController.text) ?? 0)
                      : 0,
                  type: selectedType,
                  isRandomized: isRandomized,
                  isFree: isFree,
                  publishedAt: publishedAtStr,
                );

                final messenger = ScaffoldMessenger.of(context);

                final response = await _teacherService.updateExam(
                  request,
                  exam.id,
                );

                if (!mounted) return;

                if (response.succeeded) {
                  await _fetchExams();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Exam Updated Successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${response.message}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // --- SHOW REORDER LECTURES SHEET ---
  void _showReorderLecturesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReorderLecturesSheet(
        courseId: widget.course.id,
        initialLectures: _lectures,
        teacherService: _teacherService,
        onReordered: () {
          _refreshCourse();
        },
      ),
    );
  }

  // --- SHOW REORDER MATERIALS SHEET ---
  void _showReorderMaterialsSheet(Lecture lecture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReorderMaterialsSheet(
        lectureId: lecture.id,
        initialMaterials: lecture.materials,
        teacherService: _teacherService,
        onReordered: () {
          _refreshCourse();
        },
      ),
    );
  }
}

class _ReorderLecturesSheet extends StatefulWidget {
  final int courseId;
  final List<Lecture> initialLectures;
  final TeacherService teacherService;
  final VoidCallback onReordered;

  const _ReorderLecturesSheet({
    required this.courseId,
    required this.initialLectures,
    required this.teacherService,
    required this.onReordered,
  });

  @override
  State<_ReorderLecturesSheet> createState() => _ReorderLecturesSheetState();
}

class _ReorderLecturesSheetState extends State<_ReorderLecturesSheet> {
  late List<Lecture> _localLectures;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _localLectures = List.from(widget.initialLectures);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final lecture = _localLectures.removeAt(oldIndex);
      _localLectures.insert(newIndex, lecture);
    });
  }

  Future<void> _saveOrder() async {
    setState(() => _isLoading = true);
    final orderedIds = _localLectures.map((l) => l.id).toList();
    final res = await widget.teacherService
        .reorderLectures(widget.courseId, orderedIds);

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تم ترتيب المحاضرات بنجاح'),
              backgroundColor: AppColors.success),
        );
        widget.onReordered();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ترتيب المحاضرات',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _localLectures.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final lecture = _localLectures[index];
                return Card(
                  key: ValueKey(lecture.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        const Icon(Icons.drag_indicator, color: Colors.grey),
                    title: Text(lecture.title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    subtitle: Text('${index + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.primary)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16)
                .copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveOrder,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('حفظ الترتيب',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ReorderMaterialsSheet extends StatefulWidget {
  final int lectureId;
  final List<CourseMaterial> initialMaterials;
  final TeacherService teacherService;
  final VoidCallback onReordered;

  const _ReorderMaterialsSheet({
    required this.lectureId,
    required this.initialMaterials,
    required this.teacherService,
    required this.onReordered,
  });

  @override
  State<_ReorderMaterialsSheet> createState() => _ReorderMaterialsSheetState();
}

class _ReorderMaterialsSheetState extends State<_ReorderMaterialsSheet> {
  late List<CourseMaterial> _localMaterials;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _localMaterials = List.from(widget.initialMaterials);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final material = _localMaterials.removeAt(oldIndex);
      _localMaterials.insert(newIndex, material);
    });
  }

  Future<void> _saveOrder() async {
    setState(() => _isLoading = true);
    final orderedIds = _localMaterials.map((m) => m.id).toList();
    final res = await widget.teacherService
        .reorderMaterials(widget.lectureId, orderedIds);

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم ترتيب المواد بنجاح'),
              backgroundColor: AppColors.success),
        );
        widget.onReordered();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ترتيب المواد',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _localMaterials.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final material = _localMaterials[index];
                return Card(
                  key: ValueKey(material.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        const Icon(Icons.drag_indicator, color: Colors.grey),
                    title: Text(material.title ?? 'مادة بدون عنوان',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    subtitle: Text('${index + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.primary)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16)
                .copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveOrder,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('حفظ الترتيب',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
