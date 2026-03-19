import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/course_models.dart';
import '../../../data/services/teacher_service.dart';

class AddStudentToCourseDialog extends StatefulWidget {
  final int teacherId;

  const AddStudentToCourseDialog({super.key, required this.teacherId});

  @override
  State<AddStudentToCourseDialog> createState() =>
      _AddStudentToCourseDialogState();

  /// Helper to show as a bottom sheet
  static Future<void> show(BuildContext context, {required int teacherId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddStudentToCourseDialog(teacherId: teacherId),
    );
  }
}

class _AddStudentToCourseDialogState extends State<AddStudentToCourseDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _studentEmailController = TextEditingController();
  final _teacherService = TeacherService();

  bool _isLoading = false;
  bool _isFetchingCourses = true;

  List<Course> _courses = [];
  int? _selectedCourseId;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _fetchTeacherCourses();
  }

  Future<void> _fetchTeacherCourses() async {
    try {
      final response =
          await _teacherService.getTeacherCourses(widget.teacherId);
      if (response.succeeded && response.data != null) {
        if (mounted) {
          setState(() {
            _courses = response.data!;
            _isFetchingCourses = false;
          });
          _animController.forward();
        }
      } else {
        if (mounted) setState(() => _isFetchingCourses = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingCourses = false);
    }
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate() || _selectedCourseId == null) {
      if (_selectedCourseId == null) {
        _showSnack('يرجى اختيار الكورس أولاً', isError: true);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response =
          await _teacherService.approveStudentSubscriptionByEmail(
        teacherId: widget.teacherId,
        courseId: _selectedCourseId!,
        studentEmail: _studentEmailController.text.trim(),
      );

      if (!mounted) return;

      if (response.succeeded) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('تم إضافة الطالب بنجاح',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        _showSnack(
          response.message.isEmpty ? 'فشل إضافة الطالب' : response.message,
          isError: true,
        );
      }
    } catch (_) {
      _showSnack('حدث خطأ غير متوقع', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _studentEmailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // ── Gradient Header ──────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon bubble
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إضافة طالب',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'أضف طالباً مباشرة إلى أحد كورساتك',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────
          _isFetchingCourses
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _courses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.school_outlined,
                              size: 56,
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد كورسات متاحة',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Course Picker ──
                              _SectionLabel('اختر الكورس', isDark),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 90,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _courses.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (_, i) {
                                    final course = _courses[i];
                                    final sel = _selectedCourseId == course.id;
                                    return GestureDetector(
                                      onTap: () => setState(() {
                                        _selectedCourseId = course.id;
                                      }),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        width: 140,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: sel
                                              ? AppColors.primaryGradient
                                              : null,
                                          color: sel
                                              ? null
                                              : (isDark
                                                  ? Colors.white
                                                      .withOpacity(0.05)
                                                  : Colors.grey.shade100),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: sel
                                                ? Colors.transparent
                                                : (isDark
                                                    ? Colors.white
                                                        .withOpacity(0.1)
                                                    : Colors.grey.shade200),
                                          ),
                                          boxShadow: sel
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withOpacity(0.3),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  )
                                                ]
                                              : [],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Icon(
                                              Icons.menu_book_rounded,
                                              size: 22,
                                              color: sel
                                                  ? Colors.white
                                                  : AppColors.primary,
                                            ),
                                            Text(
                                              course.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: sel
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: sel
                                                    ? Colors.white
                                                    : (isDark
                                                        ? Colors.white70
                                                        : Colors.grey.shade800),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ── Email Field ──
                              _SectionLabel('البريد الإلكتروني للطالب', isDark),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _studentEmailController,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade900,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'example@email.com',
                                  hintStyle: GoogleFonts.inter(
                                    color: isDark
                                        ? Colors.white30
                                        : Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey.shade50,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(10),
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.alternate_email_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: AppColors.primary, width: 1.5),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: AppColors.error),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: AppColors.error, width: 1.5),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'يرجى إدخال البريد الإلكتروني';
                                  if (!v.contains('@'))
                                    return 'بريد إلكتروني غير صحيح';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 26),

                              // ── Action Buttons ──
                              Row(
                                children: [
                                  // Cancel
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white12
                                                : Colors.grey.shade200,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'إلغاء',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Submit
                                  Expanded(
                                    flex: 2,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        gradient: _isLoading
                                            ? null
                                            : AppColors.primaryGradient,
                                        color: _isLoading
                                            ? AppColors.primary.withOpacity(0.5)
                                            : null,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        boxShadow: _isLoading
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withOpacity(0.35),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: InkWell(
                                          onTap: _isLoading ? null : _addStudent,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            child: Center(
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .person_add_rounded,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'إضافة الطالب',
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
