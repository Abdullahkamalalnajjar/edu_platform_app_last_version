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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
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
        title: Text(
          widget.teacherName,
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اختر',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              letterSpacing: 1,
            ),
          ),
          Text(
            'الصف الدراسي',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.displaySmall?.color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagesList() {
    final stages = _getFilteredStages();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: stages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final stage = stages[index];
        return FadeInUp(
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 100 * index),
          child: _buildStageCard(stage, index),
        );
      },
    );
  }

  Widget _buildStageCard(Map<String, dynamic> stage, int index) {
    final stageName = stage['educationStageName'] ?? 'مرحلة غير معروفة';
    // Alternate colors for variety
    final color =
        AppColors.subjectColors[index % AppColors.subjectColors.length][0];

    return GestureDetector(
      onTap: () => _onStageSelected(stage['id']),
      child: Container(
        height: 70, // Fixed height for consistent oval shape
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100), // Oval/Stadium shape
          gradient: LinearGradient(
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withOpacity(0.8),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative accent (subtle glow on side)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.05),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      stageName,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      textAlign: TextAlign.center, // Center text in the oval
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Balance the icon on the other side for perfect centering
                  const SizedBox(width: 36),
                ],
              ),
            ),

            // Arrow indicator on right (or left for RTL)
            Positioned(
              left: 20,
              child: Icon(
                Icons
                    .arrow_back_ios_rounded, // Points left in RTL (which is forward)
                color: AppColors.textSecondary.withOpacity(0.5),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "لا توجد مراحل دراسية متاحة",
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ],
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
          bottom: -size.height * 0.1,
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
                        AppColors.primary.withOpacity(0.1),
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
}
