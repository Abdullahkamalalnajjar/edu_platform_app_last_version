import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/course_models.dart';
import '../../../../data/services/course_service.dart';
import '../../../../data/services/teacher_service.dart';
import '../video_player_screen.dart';
import '../pdf_viewer_screen.dart';
import '../../student/student_exam_screen.dart';
import '../../teacher/exam_submissions_screen.dart';
import '../../teacher/add_exam_questions_screen.dart';
import '../../../widgets/dialogs/add_deadline_exception_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class LectureDetailsScreen extends StatefulWidget {
  final Lecture lecture;
  final Course course;
  final bool isTeacher;
  final bool hasApprovedSubscription;
  final bool isAssistant;
  final List<Exam> exams;
  final int lectureIndex;

  // Teacher action callbacks (from CourseDetailsScreen)
  final Future<void> Function()? onAddMaterial;
  final Future<void> Function()? onReorderMaterials;
  final Future<void> Function()? onCreateExam;
  final VoidCallback? onEditLecture;
  final VoidCallback? onDeleteLecture;
  final Future<void> Function(bool)? onToggleVisibility;

  const LectureDetailsScreen({
    super.key,
    required this.lecture,
    required this.course,
    required this.isTeacher,
    required this.hasApprovedSubscription,
    required this.isAssistant,
    required this.exams,
    required this.lectureIndex,
    this.onAddMaterial,
    this.onReorderMaterials,
    this.onCreateExam,
    this.onEditLecture,
    this.onDeleteLecture,
    this.onToggleVisibility,
  });

  @override
  State<LectureDetailsScreen> createState() => _LectureDetailsScreenState();
}

class _LectureDetailsScreenState extends State<LectureDetailsScreen>
    with TickerProviderStateMixin {
  final _courseService = CourseService();
  final _teacherService = TeacherService();

  late AnimationController _bgController;
  late TabController _tabController;
  late List<CourseMaterial> _materials;
  late List<Exam> _exams;

  @override
  void initState() {
    super.initState();
    _materials = List.from(widget.lecture.materials);
    _materials.sort((a, b) => a.index.compareTo(b.index));
    _exams = List.from(widget.exams);
    _bgController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Re-fetches the course from the server and refreshes materials & exams.
  Future<void> _refreshLecture() async {
    final response = await _courseService.getCourseById(widget.course.id);
    if (!mounted || !response.succeeded || response.data == null) return;
    final updatedCourse = response.data!;
    final updatedLecture = updatedCourse.lectures.firstWhere(
      (l) => l.id == widget.lecture.id,
      orElse: () => widget.lecture,
    );
    // Also re-fetch exams for this lecture
    final examsResp =
        await _courseService.getExamByLectureId(widget.lecture.id);
    if (!mounted) return;
    setState(() {
      _materials = List.from(updatedLecture.materials)
        ..sort((a, b) => a.index.compareTo(b.index));
      if (examsResp.succeeded && examsResp.data != null) {
        _exams = List.from(examsResp.data!);
      }
    });
  }

  String _formatDeadline(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/'
        '${dt.day.toString().padLeft(2, '0')} - '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Animated Background ──────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              final t = _bgController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [
                            Color(0xFF0A0000),
                            Color(0xFF1A0000),
                            Color(0xFF0A0000),
                          ],
                          stops: [
                            0.0,
                            0.5 + 0.15 * math.sin(t * 2 * math.pi),
                            1.0,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: const [
                            Colors.white,
                            Color(0xFFFFF5F5),
                            Colors.white,
                          ],
                          stops: [
                            0.0,
                            0.5 + 0.15 * math.sin(t * 2 * math.pi),
                            1.0,
                          ],
                        ),
                ),
              );
            },
          ),

          // ── Orbs ────────────────────────────────────────
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(isDark ? 0.30 : 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(isDark ? 0.20 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main Content ─────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark),
                _buildLectureHeader(isDark),
                const SizedBox(height: 12),
                _buildTabBar(isDark),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMaterialsTab(isDark),
                      _buildExamsTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // APPBAR
  // ════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: Theme.of(context).textTheme.bodyLarge?.color,
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.lecture.title,
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Teacher popup menu: تعديل، إخفاء/إظهار، حذف
          if (widget.isTeacher && !widget.isAssistant &&
              (widget.onEditLecture != null ||
                  widget.onToggleVisibility != null ||
                  widget.onDeleteLecture != null))
            Container(
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.15)),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  size: 20,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      widget.onEditLecture?.call();
                      break;
                    case 'toggle':
                      widget.onToggleVisibility
                          ?.call(!widget.lecture.isVisible);
                      break;
                    case 'delete':
                      widget.onDeleteLecture?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (widget.onToggleVisibility != null)
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(children: [
                        Icon(
                          widget.lecture.isVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.lecture.isVisible ? 'إخفاء' : 'إظهار',
                          style: GoogleFonts.inter(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color),
                        ),
                      ]),
                    ),
                  if (widget.onEditLecture != null) ...[
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
                        Text('تعديل',
                            style: GoogleFonts.inter(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color)),
                      ]),
                    ),
                  ],
                  if (widget.onDeleteLecture != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_rounded,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('حذف المحاضرة',
                            style: GoogleFonts.inter(
                                color: AppColors.error)),
                      ]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // LECTURE HEADER CARD
  // ════════════════════════════════════════════════════════
  Widget _buildLectureHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FadeInDown(
        duration: const Duration(milliseconds: 500),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(isDark ? 0.25 : 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(isDark ? 0.1 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFE53935)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${widget.lectureIndex + 1}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lecture.title,
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_materials.length} مواد  •  ${_exams.length} اختبار',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.lecture.isVisible)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'مخفية',
                    style: GoogleFonts.tajawal(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // TAB BAR
  // ════════════════════════════════════════════════════════
  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFFE53935)],
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
          labelStyle: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            // Materials Tab
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 15),
                  const SizedBox(width: 6),
                  const Text('المواد'),
                  if (_materials.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_materials.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Exams Tab
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.quiz_rounded, size: 15),
                  const SizedBox(width: 6),
                  const Text('الاختبارات'),
                  if (_exams.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_exams.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // MATERIALS TAB
  // ════════════════════════════════════════════════════════
  Widget _buildMaterialsTab(bool isDark) {
    final hasTeacherActions = widget.isTeacher &&
        (widget.onAddMaterial != null ||
            widget.onReorderMaterials != null ||
            widget.onCreateExam != null);

    if (_materials.isEmpty && !hasTeacherActions) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_rounded,
              size: 56,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.3),
            ),
            const SizedBox(height: 14),
            Text(
              'لم يتم إضافة مواد بعد',
              style: GoogleFonts.tajawal(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // Materials list
        if (_materials.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'لم يتم إضافة مواد بعد',
                style: GoogleFonts.tajawal(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...List.generate(
            _materials.length,
            (i) => FadeInUp(
              duration: const Duration(milliseconds: 400),
              delay: Duration(milliseconds: 60 * i),
              child: _buildMaterialCard(_materials[i], isDark),
            ),
          ),

        // Teacher action buttons
        if (hasTeacherActions) ..._buildTeacherActions(isDark),
      ],
    );
  }

  List<Widget> _buildTeacherActions(bool isDark) {
    return [
      const SizedBox(height: 8),
      // Add Material
      if (widget.onAddMaterial != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final btnColor = isDark
                  ? Color.lerp(AppColors.success, Colors.white, 0.3)!
                  : AppColors.success;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await widget.onAddMaterial?.call();
                    await _refreshLecture();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: btnColor.withOpacity(isDark ? 0.15 : 0.08),
                      border: Border.all(
                          color: btnColor.withOpacity(isDark ? 0.5 : 0.3),
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            size: 20, color: btnColor),
                        const SizedBox(width: 8),
                        Text(
                          'إضافة مادة جديدة',
                          style: GoogleFonts.inter(
                              color: btnColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      // Reorder Materials
      if (widget.onReorderMaterials != null && _materials.length > 1)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await widget.onReorderMaterials?.call();
                await _refreshLecture();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.reorder_rounded,
                        size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'ترتيب المواد',
                      style: GoogleFonts.inter(
                          color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      // Create Exam
      if (widget.onCreateExam != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await widget.onCreateExam?.call();
                await _refreshLecture();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.quiz_rounded,
                        size: 20, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'إنشاء اختبار جديد',
                      style: GoogleFonts.inter(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 16),
    ];
  }

  // ════════════════════════════════════════════════════════
  // EXAMS TAB
  // ════════════════════════════════════════════════════════
  Widget _buildExamsTab(bool isDark) {
    if (_exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_rounded,
              size: 56,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.3),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد اختبارات لهذه المحاضرة',
              style: GoogleFonts.tajawal(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      physics: const BouncingScrollPhysics(),
      itemCount: _exams.length,
      itemBuilder: (ctx, i) => FadeInUp(
        duration: const Duration(milliseconds: 400),
        delay: Duration(milliseconds: 60 * i),
        child: _buildExamCard(_exams[i], isDark),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // MATERIAL CARD  (unchanged)
  // ════════════════════════════════════════════════════════
  Widget _buildMaterialCard(CourseMaterial material, bool isDark) {
    final isVideo = material.type == 'Video';
    final isPdf = material.type == 'Pdf';
    final isHomework = material.type == 'Homework';
    final Color iconColor = isVideo
        ? const Color(0xFFFF5252)
        : isPdf
            ? const Color(0xFFE57373)
            : isHomework
                ? const Color(0xFF64B5F6)
                : AppColors.textSecondary;
    final IconData icon = isVideo
        ? Icons.play_circle_rounded
        : isPdf
            ? Icons.picture_as_pdf_rounded
            : isHomework
                ? Icons.assignment_rounded
                : Icons.insert_drive_file_rounded;
    final canOpen = widget.isTeacher ||
        material.isFree ||
        widget.hasApprovedSubscription;

    String? thumbnailUrl;
    if (isVideo) {
      final videoId = YoutubePlayer.convertUrlToId(material.fileUrl);
      if (videoId != null) {
        thumbnailUrl =
            'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
      }
    }

    return GestureDetector(
      onTap: canOpen ? () => _openMaterial(material) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: iconColor.withOpacity(isDark ? 0.2 : 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover Image (if available) ──────────────────────
            if (material.coverImageUrl != null &&
                material.coverImageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  material.coverImageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 150,
                      color: iconColor.withOpacity(0.05),
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
              const SizedBox(height: 12),
            ],
            // ── Content Row ─────────────────────────────────────
            Row(
              children: [
                // Thumbnail / Icon
                if (isVideo && thumbnailUrl != null)
                  Container(
                    width: 90,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(thumbnailUrl),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: iconColor.withOpacity(0.2),
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                const SizedBox(width: 14),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title ?? material.type,
                        style: GoogleFonts.tajawal(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (canOpen)
                        Text(
                          isVideo ? 'اضغط للمشاهدة' : 'اضغط للفتح',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // Free/Paid badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (material.isFree ? AppColors.success : AppColors.error)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          (material.isFree ? AppColors.success : AppColors.error)
                              .withOpacity(0.25),
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
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        material.isFree ? 'مجاني' : 'مدفوع',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: material.isFree
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  canOpen
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.lock_rounded,
                  size: 16,
                  color: canOpen
                      ? AppColors.primary.withOpacity(0.6)
                      : AppColors.error.withOpacity(0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // EXAM CARD  (unchanged)
  // ════════════════════════════════════════════════════════
  Widget _buildExamCard(Exam exam, bool isDark) {
    final isAssignment = exam.type == 'Assignment';
    final themeColor = isAssignment ? Colors.blue : Colors.orange;
    final examIcon =
        isAssignment ? Icons.assignment_rounded : Icons.quiz_rounded;
    final canAccess = widget.isTeacher ||
        widget.hasApprovedSubscription ||
        exam.isFree;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: themeColor.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _openExam(exam, canAccess),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeColor.shade400,
                          themeColor.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(examIcon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.title,
                          style: GoogleFonts.tajawal(
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.format_list_numbered_rounded,
                              size: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${exam.questions.length} أسئلة',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.timer_rounded,
                              size: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${exam.durationInMinutes} دقيقة',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    canAccess
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.lock_rounded,
                    size: 16,
                    color: canAccess
                        ? Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                        : AppColors.error,
                  ),
                ],
              ),
            ),
          ),
          // Teacher Actions
          if (widget.isTeacher || widget.isAssistant) ...[
            Divider(height: 1, color: themeColor.withOpacity(0.15)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _examAction(
                      Icons.people_alt_rounded,
                      'تسليمات',
                      themeColor,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExamSubmissionsScreen(
                              lectureId: exam.lectureId,
                              lectureTitle: exam.lectureName ?? '',
                              examId: exam.id,
                              courseId: widget.course.id,
                            ),
                          ),
                        );
                      },
                    ),
                    _examAction(
                      Icons.visibility_rounded,
                      'معاينة',
                      themeColor,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentExamScreen(
                              lectureId: exam.lectureId,
                              examId: exam.id,
                              lectureTitle: exam.lectureName ?? '',
                              isTeacher: true,
                            ),
                          ),
                        );
                      },
                    ),
                    _examAction(
                      Icons.edit_note_rounded,
                      'تعديل الأسئلة',
                      themeColor,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddExamQuestionsScreen(
                              examId: exam.id,
                              existingExam: exam,
                            ),
                          ),
                        );
                      },
                    ),
                    _examAction(
                      exam.isVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      exam.isVisible ? 'إخفاء' : 'إظهار',
                      themeColor,
                      () => _toggleExamVisibility(exam),
                    ),
                    _examAction(
                      Icons.more_time_rounded,
                      'استثناء',
                      themeColor,
                      () {
                        showDialog(
                          context: context,
                          builder: (_) => AddDeadlineExceptionDialog(
                            courseId: widget.course.id,
                            examId: exam.id,
                            teacherId: widget.course.teacherId,
                          ),
                        );
                      },
                    ),
                    if (!widget.isAssistant)
                      _examAction(
                        Icons.delete_outline_rounded,
                        'حذف',
                        AppColors.error,
                        () => _deleteExam(exam.id),
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

  Widget _examAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════
  void _openMaterial(CourseMaterial material) async {
    if (material.type == 'Video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(videoUrl: material.fileUrl),
        ),
      );
    } else {
      final isUrl = material.fileUrl.startsWith('http');
      final isPdf = material.fileUrl.toLowerCase().contains('.pdf') ||
          material.type == 'Pdf';
      if (isPdf && isUrl) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              pdfUrl: material.fileUrl,
              title: material.title ?? 'عرض الملف',
            ),
          ),
        );
      } else if (isUrl) {
        final uri = Uri.parse(material.fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (isPdf) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              pdfUrl: material.fileUrl,
              title: material.title ?? 'عرض الملف',
              isLocal: true,
            ),
          ),
        );
      } else {
        await OpenFilex.open(material.fileUrl);
      }
    }
  }

  Future<void> _openExam(Exam exam, bool canAccess) async {
    if (!canAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب الاشتراك في الكورس لدخول الامتحان'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (!widget.isTeacher) {
      final resp = await _courseService.checkExamAccess(examId: exam.id);
      if (resp.succeeded && resp.data != null) {
        final a = resp.data!;
        if (a.hasException && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ لديك استثناء${a.extendedDeadline != null ? " - الموعد الجديد: ${_formatDeadline(a.extendedDeadline!)}" : ""}',
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (!a.canAccess && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ الموعد النهائي انتهى${a.deadline != null ? " في ${_formatDeadline(a.deadline!)}" : ""}',
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentExamScreen(
            lectureId: exam.lectureId,
            examId: exam.id,
            lectureTitle: exam.lectureName ?? '',
            isTeacher: widget.isTeacher,
          ),
        ),
      );
    }
  }

  Future<void> _deleteExam(int examId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'حذف الاختبار',
          style:
              TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
        content: Text(
          'هل أنت متأكد أنك تريد حذف هذا الاختبار؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color),
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
      final resp = await _teacherService.deleteExam(examId);
      if (resp.succeeded && mounted) {
        setState(() => _exams.removeWhere((e) => e.id == examId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الاختبار')),
        );
      }
    }
  }

  Future<void> _toggleExamVisibility(Exam exam) async {
    final resp = await _teacherService.changeExamVisibility(
      examId: exam.id,
      isVisible: !exam.isVisible,
    );
    if (resp.succeeded && mounted) {
      setState(() {
        final i = _exams.indexWhere((e) => e.id == exam.id);
        if (i != -1) {
          _exams[i] = Exam(
            id: exam.id,
            title: exam.title,
            lectureId: exam.lectureId,
            lectureName: exam.lectureName,
            questions: exam.questions,
            isFree: exam.isFree,
            isVisible: !exam.isVisible,
            deadline: exam.deadline,
            durationInMinutes: exam.durationInMinutes,
            type: exam.type,
            isRandomized: exam.isRandomized,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exam.isVisible
                ? 'تم إخفاء الاختبار عن الطلاب'
                : 'تم إظهار الاختبار للطلاب',
          ),
        ),
      );
    }
  }
}