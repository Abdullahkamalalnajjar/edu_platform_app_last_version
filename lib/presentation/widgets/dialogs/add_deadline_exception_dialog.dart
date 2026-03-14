import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/course_models.dart';
import '../../../data/services/teacher_service.dart';
import '../primary_button.dart';
import '../custom_text_field.dart';

class AddDeadlineExceptionDialog extends StatefulWidget {
  final int courseId;
  final int examId;
  final int teacherId;

  const AddDeadlineExceptionDialog({
    super.key,
    required this.courseId,
    required this.examId,
    required this.teacherId,
  });

  @override
  State<AddDeadlineExceptionDialog> createState() =>
      _AddDeadlineExceptionDialogState();
}

class _AddDeadlineExceptionDialogState
    extends State<AddDeadlineExceptionDialog> {
  final _teacherService = TeacherService();
  final _reasonController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<EnrolledStudent> _students = [];
  EnrolledStudent? _selectedStudent;
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    final response = await _teacherService.getEnrolledStudents(
      widget.courseId,
      teacherId: widget.teacherId,
    );
    if (mounted) {
      if (response.succeeded && response.data != null) {
        setState(() {
          _students = response.data!;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        // If 400 or whatever, show empty or error
        if (response.message.isNotEmpty) {
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

  Future<void> _handleSubmit() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الطالب')));
      return;
    }
    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد الموعد الجديد')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final request = DeadlineExceptionRequest(
      examId: widget.examId,
      studentId: _selectedStudent!.studentId,
      extendedDeadline: _selectedDeadline!,
      reason: _reasonController.text,
      allowedAfterDeadline: true,
    );

    final response = await _teacherService.createDeadlineException(request);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (response.succeeded) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الاستثناء بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
              dialogBackgroundColor: Colors.white,
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDeadline = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'إضافة استثناء',
        style: GoogleFonts.outfit(
          color: Theme.of(context).textTheme.titleLarge?.color,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_students.isEmpty)
                Text(
                  'لا يوجد طلاب مسجلين',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                )
              else
                Column(
                  children: [
                    // Student Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<EnrolledStudent>(
                          isExpanded: true,
                          hint: Text(
                            'اختر الطالب',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          value: _selectedStudent,
                          dropdownColor: AppColors.surface,
                          items: _students.map((student) {
                            return DropdownMenuItem(
                              value: student,
                              child: Text(
                                student.studentName,
                                style: GoogleFonts.inter(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedStudent = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date Picker
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.textSecondary.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedDeadline == null
                                    ? 'تحديد الموعد النهائي'
                                    : '${_selectedDeadline!.year}/${_selectedDeadline!.month.toString().padLeft(2, '0')}/${_selectedDeadline!.day.toString().padLeft(2, '0')} - ${_selectedDeadline!.hour.toString().padLeft(2, '0')}:${_selectedDeadline!.minute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.inter(
                                  color: _selectedDeadline == null
                                      ? Theme.of(context).textTheme.bodyMedium?.color
                                      : Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reason Text Field
                    CustomTextField(
                      controller: _reasonController,
                      hintText: 'سبب الاستثناء (اختياري)',
                      maxLines: 2,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
        if (!_isLoading && _students.isNotEmpty)
          PrimaryButton(
            onPressed: _handleSubmit,
            text: 'حفظ',
            isLoading: _isSubmitting,
            width: 100,
            height: 40,
          ),
      ],
    );
  }
}
