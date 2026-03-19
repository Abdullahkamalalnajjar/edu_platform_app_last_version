import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../data/models/course_models.dart';

class StudentScoreCard extends StatelessWidget {
  final StudentCourseScore studentScore;

  const StudentScoreCard({super.key, required this.studentScore});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = studentScore.percentage;
    final Color percentColor = percentage >= 80
        ? const Color(0xFF00E676)
        : percentage >= 50
            ? const Color(0xFFFFD740)
            : const Color(0xFFFF5252);

    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1E1215),
                        const Color(0xFF150D10),
                        const Color(0xFF0F0A0C),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFFFF8F8),
                        Colors.white,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(isDark ? 0.08 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // ── Header ─────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.2),
                              AppColors.primary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ملخص أدائك في الكورس',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Main Stats Row ─────────────────────────
                  Expanded(
                    child: Row(
                      children: [
                        // ── Score Card ──
                        Expanded(
                          child: _buildGlassCard(
                            isDark: isDark,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade400),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${studentScore.totalScore.toStringAsFixed(1)} / ${studentScore.maxScore}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'إجمالي الدرجات',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textSecondary.withOpacity(0.7)
                                        : AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── Percentage Card ──
                        Expanded(
                          child: _buildGlassCard(
                            isDark: isDark,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: (percentage / 100).clamp(0.0, 1.0),
                                        strokeWidth: 3.5,
                                        backgroundColor: isDark
                                            ? Colors.white.withOpacity(0.06)
                                            : Colors.grey.withOpacity(0.15),
                                        valueColor: AlwaysStoppedAnimation(percentColor),
                                      ),
                                      Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: percentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'النسبة المئوية',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textSecondary.withOpacity(0.7)
                                        : AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── Completed Exams ──
                        Expanded(
                          child: _buildGlassCard(
                            isDark: isDark,
                            accentColor: AppColors.success,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                                const SizedBox(height: 4),
                                Text(
                                  '${studentScore.completedExamsCount}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'مكتملة',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textSecondary.withOpacity(0.7)
                                          : AppColors.textMutedLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── Total Exams ──
                        Expanded(
                          child: _buildGlassCard(
                            isDark: isDark,
                            accentColor: AppColors.info,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_rounded, size: 18, color: AppColors.info),
                                const SizedBox(height: 4),
                                Text(
                                  '${studentScore.examsCount}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'إجمالي',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textSecondary.withOpacity(0.7)
                                          : AppColors.textMutedLight,
                                    ),
                                  ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required bool isDark,
    required Widget child,
    Color? accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: accentColor != null
            ? accentColor.withOpacity(isDark ? 0.06 : 0.04)
            : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor != null
              ? accentColor.withOpacity(isDark ? 0.12 : 0.1)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.12)),
        ),
      ),
      child: child,
    );
  }
}
