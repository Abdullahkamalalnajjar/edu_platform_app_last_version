import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/course_models.dart';
import '../../../data/services/teacher_service.dart';
import '../../../data/services/token_service.dart';
import '../primary_button.dart';

class AddStudentToCourseDialog extends StatefulWidget {
  final int teacherId;

  const AddStudentToCourseDialog({super.key, required this.teacherId});

  @override
  State<AddStudentToCourseDialog> createState() =>
      _AddStudentToCourseDialogState();
}

class _AddStudentToCourseDialogState extends State<AddStudentToCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _studentEmailController = TextEditingController();
  final _teacherService = TeacherService();

  bool _isLoading = false;
  bool _isFetchingCourses = true;

  List<Course> _courses = [];
  int? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _fetchTeacherCourses();
  }

  Future<void> _fetchTeacherCourses() async {
    try {
      final response = await _teacherService.getTeacherCourses(
        widget.teacherId,
      );
      if (response.succeeded && response.data != null) {
        if (mounted) {
          setState(() {
            _courses = response.data!;
            _isFetchingCourses = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isFetchingCourses = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message.isEmpty
                    ? 'فشل في تحميل الكورسات'
                    : response.message,
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingCourses = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء تحميل الكورسات'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate() || _selectedCourseId == null) {
      if (_selectedCourseId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار الكورس'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final studentEmail = _studentEmailController.text.trim();
      if (studentEmail.isEmpty) return;

      final response = await _teacherService.approveStudentSubscriptionByEmail(
        teacherId: widget.teacherId,
        courseId: _selectedCourseId!,
        studentEmail: studentEmail,
      );

      if (!mounted) return;

      if (response.succeeded) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الطالب بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message.isEmpty ? 'فشل إضافة الطالب' : response.message,
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ غير متوقع'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _studentEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إضافة طالب للكورس',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isFetchingCourses)
              const Center(child: CircularProgressIndicator())
            else if (_courses.isEmpty)
              Center(
                child: Text(
                  'لا توجد كورسات متاحة',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'اختر الكورس',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.surface),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.surface),
                        ),
                      ),
                      value: _selectedCourseId,
                      items: _courses.map((course) {
                        return DropdownMenuItem<int>(
                          value: course.id,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 200),
                            child: Text(
                              course.title,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              maxLines: 1,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCourseId = value);
                      },
                      validator: (value) => value == null ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _studentEmailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني للطالب',
                        hintText: 'example@email.com',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.surface),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.surface),
                        ),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال البريد الإلكتروني';
                        }
                        if (!value.contains('@')) {
                          return 'البريد الإلكتروني غير صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      text: 'إضافة الطالب',
                      onPressed: _addStudent,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
