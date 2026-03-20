import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/presentation/screens/teacher/teacher_courses_screen.dart';

class SelectGradeScreen extends StatefulWidget {
  final int teacherId;
  final String teacherName;
  final Map<String, dynamic> teacherData;

  const SelectGradeScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.teacherData,
  });

  @override
  State<SelectGradeScreen> createState() => _SelectGradeScreenState();
}

class _SelectGradeScreenState extends State<SelectGradeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _backgroundController;
  List<Map<String, dynamic>> _stages = [];

  // Grade icons for visual variety
  static const List<IconData> _gradeIcons = [
    Icons.menu_book_rounded,
    Icons.auto_stories_rounded,
    Icons.school_rounded,
    Icons.workspace_premium_rounded,
    Icons.military_tech_rounded,
    Icons.emoji_events_rounded,
    Icons.star_rounded,
    Icons.psychology_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _extractStages();
  }

  void _extractStages() {
    final stagesList = widget.teacherData['teacherEducationStages'] as List?;
    if (stagesList != null) {
      _stages = List<Map<String, dynamic>>.from(stagesList);
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  void _onStageSelected(int stageId) {
    // Create a copy of teacherData and include the selected stage ID
    final updatedTeacherData = Map<String, dynamic>.from(widget.teacherData);
    updatedTeacherData['selectedStageId'] = stageId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherCoursesScreen(
          teacherId: widget.teacherId,
          teacherName: widget.teacherName,
          teacherData: updatedTeacherData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor.withOpacity(0.8) : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.glassBorder : AppColors.primary.withOpacity(0.15)),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        titleSpacing: 0,
        title: Text(
          widget.teacherName,
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          overflow: TextOverflow.visible,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (isDark) _buildAnimatedBackground(),
          _buildDecorativeOrbs(size),
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _getFilteredStages().isEmpty
              ? _buildEmptyState()
              : _buildStagesList(),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredStages() {
    // Filter out stages with empty names or invalid IDs if necessary
    return _stages.where((s) => s['educationStageName'] != null).toList();
  }

  Widget _buildHeader() {
    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + Title in same row
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.2),
                        AppColors.primaryDark.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'اختر الصف الدراسي',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.displaySmall?.color,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'اختر المرحلة الدراسية اللي عايز تشوف دوراتها',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Gradient divider
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStagesList() {
    final stages = _getFilteredStages();
    final isGrid = stages.length >= 4;

    if (isGrid) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: stages.length,
          itemBuilder: (context, index) {
            final stage = stages[index];
            return FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: Duration(milliseconds: 80 * index),
              child: _buildStageCardGrid(stage, index),
            );
          },
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: stages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final stage = stages[index];
        return FadeInUp(
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 100 * index),
          child: _buildStageCardList(stage, index),
        );
      },
    );
  }

  // Grid card for 4+ stages
  Widget _buildStageCardGrid(Map<String, dynamic> stage, int index) {
    final stageName = stage['educationStageName'] ?? 'مرحلة غير معروفة';
    final colors = AppColors.subjectColors[index % AppColors.subjectColors.length];
    final icon = _gradeIcons[index % _gradeIcons.length];

    return GestureDetector(
      onTap: () => _onStageSelected(stage['id']),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors[0].withOpacity(0.15),
              colors[1].withOpacity(0.08),
            ],
          ),
          border: Border.all(
            color: colors[0].withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decorative circle
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[0].withOpacity(0.08),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors[0], colors[1]],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  // Name & arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stageName,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.displaySmall?.color ?? Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'عرض الدورات',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: colors[0].withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_back_ios_rounded,
                            size: 9,
                            color: colors[0].withOpacity(0.8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // List card for fewer stages
  Widget _buildStageCardList(Map<String, dynamic> stage, int index) {
    final stageName = stage['educationStageName'] ?? 'مرحلة غير معروفة';
    final colors = AppColors.subjectColors[index % AppColors.subjectColors.length];
    final icon = _gradeIcons[index % _gradeIcons.length];

    return GestureDetector(
      onTap: () => _onStageSelected(stage['id']),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              colors[0].withOpacity(0.12),
              colors[1].withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: colors[0].withOpacity(0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Arrow (RTL = arrow is on the right visually, left logically)
            Icon(
              Icons.arrow_back_ios_rounded,
              size: 16,
                color: Colors.white24,
            ),
            const SizedBox(width: 12),
            // Stage name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stageName,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.displaySmall?.color ?? Colors.white,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اضغط لعرض الدورات المتاحة',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white30,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors[0], colors[1]],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colors[0].withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Icon(
                Icons.school_outlined,
                size: 36,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد مراحل دراسية متاحة',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0A0A0A),
                const Color(0xFF1A0A0A),
                const Color(0xFF0A0A0A),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned(
          top: -size.height * 0.08,
          right: -size.width * 0.15,
          child: AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  15 * math.sin(_backgroundController.value * 2 * math.pi),
                  15 * math.cos(_backgroundController.value * 2 * math.pi),
                ),
                child: Container(
                  width: size.width * 0.5,
                  height: size.width * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(isDark ? 0.2 : 0.08),
                        AppColors.primaryDark.withOpacity(isDark ? 0.05 : 0.02),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: -size.height * 0.12,
          left: -size.width * 0.2,
          child: AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -20 * math.sin(_backgroundController.value * 2 * math.pi),
                  20 * math.cos(_backgroundController.value * 2 * math.pi),
                ),
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryDark.withOpacity(isDark ? 0.15 : 0.06),
                        AppColors.primary.withOpacity(isDark ? 0.04 : 0.02),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
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
}
