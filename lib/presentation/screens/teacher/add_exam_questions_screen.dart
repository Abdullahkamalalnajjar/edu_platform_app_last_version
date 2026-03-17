import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/course_models.dart';
import 'package:edu_platform_app/data/services/teacher_service.dart';
import 'package:edu_platform_app/presentation/screens/teacher/custom_image_crop_screen.dart';

class AddExamQuestionsScreen extends StatefulWidget {
  final int examId;
  final Exam? existingExam;

  const AddExamQuestionsScreen({
    super.key,
    required this.examId,
    this.existingExam,
  });

  @override
  State<AddExamQuestionsScreen> createState() => _AddExamQuestionsScreenState();
}

class _AddExamQuestionsScreenState extends State<AddExamQuestionsScreen> {
  final _teacherService = TeacherService();
  final List<QuestionRequest> _addedQuestions =
      []; // Newly added local questions
  List<Question> _existingQuestions = []; // Fetched/Passed existing questions
  bool _isLoading = false;

  // Editing State
  int? _editingQuestionId;
  bool get _isEditing => _editingQuestionId != null;

  final _contentController = TextEditingController();
  final _scoreController = TextEditingController(text: '1');
  final _correctAnswerController =
      TextEditingController(); // For text-based correct answer
  String _selectedQuestionType = 'Text';
  String _selectedAnswerType = 'TextAnswer';
  bool _correctByAssistant = false;
  XFile? _selectedFile;
  XFile? _selectedCorrectAnswerFile;
  String? _existingQuestionImageUrl;

  final List<Map<String, dynamic>> _tempOptions = [];
  final _optionController = TextEditingController();
  bool _optionIsCorrect = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingExam != null) {
      _existingQuestions = widget.existingExam!.questions;
    }
  }

  void _clearInputs({bool keepSettings = false}) {
    // Only clear content when not keeping settings (i.e., when canceling edit)
    if (!keepSettings) {
      _contentController.clear();
    }

    // Always clear file picker for question (new question needs new file)
    _selectedFile = null;
    _existingQuestionImageUrl = null;

    if (!keepSettings) {
      // Clear all settings (used when canceling edit)
      _scoreController.text = '1';
      _correctAnswerController.clear();
      _selectedQuestionType = 'Text';
      _selectedAnswerType = 'TextAnswer';
      _correctByAssistant = false;
      _selectedCorrectAnswerFile = null;
      _tempOptions.clear();
      _optionController.clear();
      _optionIsCorrect = false;
    }
    // When keepSettings = true, keep content, settings, and options for quick entry of similar questions

    setState(() {
      _editingQuestionId = null;
      _editingOptionIndex = null;
    });
  }

  Future<void> _deleteQuestion(int questionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'حذف السؤال',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا السؤال؟',
          style: GoogleFonts.inter(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final response = await _teacherService.deleteQuestion(questionId);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.succeeded) {
      setState(() {
        _existingQuestions.removeWhere((q) => q.id == questionId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف السؤال بنجاح'),
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

  void _startEditing(Question question) {
    setState(() {
      _editingQuestionId = question.id;
      _scoreController.text = question.score.toString();
      _correctAnswerController.text =
          question.correctAnswer ?? '';
      _selectedQuestionType = question.questionType.isEmpty
          ? 'Text'
          : question.questionType;
      _selectedAnswerType = question.answerType.isEmpty
          ? 'TextAnswer'
          : question.answerType;
      _correctByAssistant = question.correctByAssistant;

      // If Image type, store URL as existing image and clear text content
      if (_selectedQuestionType == 'Image' &&
          question.content.isNotEmpty &&
          (question.content.startsWith('http') ||
              question.content.startsWith('/'))) {
        _existingQuestionImageUrl = question.content;
        _contentController.clear();
      } else {
        _existingQuestionImageUrl = null;
        _contentController.text = question.content;
      }

      _tempOptions.clear();
      for (var opt in question.options) {
        _tempOptions.add({
          'content': opt.content,
          'isCorrect': opt.isCorrect,
          'id': opt.id,
        });
      }
    });
  }

  Future<void> _submitQuestion() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال محتوى السؤال')),
      );
      return;
    }

    if (_selectedAnswerType == 'MCQ' && _tempOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إضافة خيارين على الأقل للاختيار من متعدد'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final request = QuestionRequest(
      questionType: _selectedQuestionType,
      content: _contentController.text,
      answerType: _selectedAnswerType,
      score: int.tryParse(_scoreController.text) ?? 1,
      examId: widget.examId,
      filePath: _selectedFile?.path,
      fileBytes: _selectedFile != null
          ? await _selectedFile!.readAsBytes()
          : null,
      fileName: _selectedFile?.name,
      correctByAssistant: _correctByAssistant,
      correctAnswerFilePath: _selectedCorrectAnswerFile?.path,
      correctAnswerFileBytes: _selectedCorrectAnswerFile != null
          ? await _selectedCorrectAnswerFile!.readAsBytes()
          : null,
      correctAnswerFileName: _selectedCorrectAnswerFile?.name,
      // Use text from controller if provided, otherwise null for MCQ
      correctAnswer:
          _selectedAnswerType != 'MCQ' &&
              _correctAnswerController.text.isNotEmpty
          ? _correctAnswerController.text
          : null,
    );

    if (_isEditing) {
      // Update Existing Question
      final response = await _teacherService.updateQuestion(
        request,
        _editingQuestionId!,
      );

      if (response.succeeded) {
        if (_selectedAnswerType == 'MCQ') {
          // Sync Options
          final originalQuestion = _existingQuestions.firstWhere(
            (q) => q.id == _editingQuestionId,
          );
          final originalOptions = originalQuestion.options;

          // 1. Identify Removed Options
          final currentOptionIds = _tempOptions
              .where((opt) => opt.containsKey('id'))
              .map((opt) => opt['id'] as int)
              .toList();

          for (var oldOpt in originalOptions) {
            if (!currentOptionIds.contains(oldOpt.id)) {
              await _teacherService.deleteQuestionOption(oldOpt.id);
            }
          }

          // 2. Identify New & Updated Options
          for (var opt in _tempOptions) {
            if (opt.containsKey('id')) {
              // Update existing option
              final optRequest = QuestionOptionRequest(
                id: opt['id'] as int,
                content: opt['content'],
                isCorrect: opt['isCorrect'],
                questionId: _editingQuestionId!,
              );
              await _teacherService.updateQuestionOption(optRequest);
            } else {
              // Create new option
              final optRequest = QuestionOptionRequest(
                content: opt['content'],
                isCorrect: opt['isCorrect'],
                questionId: _editingQuestionId!,
              );
              await _teacherService.createQuestionOption(optRequest);
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث السؤال بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );

        // Fetch fresh data to ensure everything is in sync
        final examResponse = await _teacherService.getExamById(widget.examId);
        if (examResponse.succeeded && examResponse.data != null) {
          setState(() {
            _existingQuestions = examResponse.data!.questions;
          });
        }

        _clearInputs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      // Create New Question
      final response = await _teacherService.createQuestion(request);

      if (response.succeeded && response.data != null) {
        final questionId = response.data!;

        // Submit options if MCQ
        if (_selectedAnswerType == 'MCQ') {
          for (var opt in _tempOptions) {
            final optRequest = QuestionOptionRequest(
              content: opt['content'],
              isCorrect: opt['isCorrect'],
              questionId: questionId,
            );
            await _teacherService.createQuestionOption(optRequest);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة السؤال والخيارات بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );

        // Fetch fresh data to ensure everything is in sync and show new question in the main list
        final examResponse = await _teacherService.getExamById(widget.examId);
        if (examResponse.succeeded && examResponse.data != null) {
          setState(() {
            _existingQuestions = examResponse.data!.questions;
          });
        }

        // Keep settings for quick entry of similar questions
        _clearInputs(keepSettings: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  void _addTempOption() {
    if (_optionController.text.isEmpty) return;
    setState(() {
      if (_editingOptionIndex != null) {
        // Update existing option
        _tempOptions[_editingOptionIndex!]['content'] = _optionController.text
            .trim();
        _tempOptions[_editingOptionIndex!]['isCorrect'] = _optionIsCorrect;
        _editingOptionIndex = null;
      } else {
        // Add new option
        _tempOptions.add({
          'content': _optionController.text.trim(),
          'isCorrect': _optionIsCorrect,
        });
      }
      _optionController.clear();
      _optionIsCorrect = false;
    });
  }

  // State for editing an option
  int? _editingOptionIndex;

  void _startEditingOption(int index) {
    setState(() {
      _editingOptionIndex = index;
      _optionController.text = _tempOptions[index]['content'];
      _optionIsCorrect = _tempOptions[index]['isCorrect'];
    });
  }

  void _cancelEditingOption() {
    setState(() {
      _editingOptionIndex = null;
      _optionController.clear();
      _optionIsCorrect = false;
    });
  }

  void _toggleOptionCorrect(int index) {
    setState(() {
      _tempOptions[index]['isCorrect'] = !_tempOptions[index]['isCorrect'];
    });
  }

  Future<void> _finishExamCreation() async {
    print('🎯 _finishExamCreation called - Finishing without notifications');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنهاء إنشاء الاختبار بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل السؤال' : 'إضافة أسئلة الاختبار',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isEditing
                              ? 'تعديل تفاصيل السؤال'
                              : 'تفاصيل السؤال الجديد',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (_isEditing)
                          IconButton(
                            onPressed: _clearInputs,
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.error,
                            ),
                            tooltip: 'إلغاء التعديل',
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Show existing image preview when editing an Image question
                    if (_existingQuestionImageUrl != null) ...[
                      Text(
                        'صورة السؤال الحالية',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: EdgeInsets.zero,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(color: Colors.black87),
                                      ),
                                      InteractiveViewer(
                                        panEnabled: true,
                                        minScale: 0.5,
                                        maxScale: 4.0,
                                        child: Center(
                                          child: Image.network(
                                            _existingQuestionImageUrl!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image, color: Colors.white, size: 64),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 40,
                                        right: 20,
                                        child: IconButton(
                                          onPressed: () => Navigator.pop(context),
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Icon(Icons.close, color: Colors.white, size: 24),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _existingQuestionImageUrl!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.broken_image, color: AppColors.error, size: 48),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _existingQuestionImageUrl = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else
                      _buildTextField(
                        controller: _contentController,
                        label: 'محتوى السؤال',
                        maxLines: 3,
                      ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'نوع السؤال',
                      value: _selectedQuestionType,
                      items: const {'Text': 'نص', 'Image': 'صورة'},
                      onChanged: (val) =>
                          setState(() => _selectedQuestionType = val!),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'نوع الإجابة',
                      value: _selectedAnswerType,
                      items: const {
                        'MCQ': 'اختيار من متعدد',
                        'ImageAnswer': 'إجابة بصورة',
                        'TextAnswer': 'إجابة نصية',
                      },
                      onChanged: (val) =>
                          setState(() => _selectedAnswerType = val!),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _scoreController,
                      label: 'الدرجة',
                      isNumeric: true,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'تصحيح بواسطة المساعد',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 14,
                        ),
                      ),
                      value: _correctByAssistant,
                      activeColor: AppColors.primary,
                      onChanged: (val) =>
                          setState(() => _correctByAssistant = val),
                    ),
                    _buildFilePicker(),
                    const SizedBox(height: 16),
                    // Show correct answer inputs if not MCQ
                    if (_selectedAnswerType != 'MCQ') ...[
                      // Text field for correct answer
                      _buildTextField(
                        controller: _correctAnswerController,
                        label: 'الإجابة الصحيحة (نص)',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      // File picker for correct answer image/file
                      _buildCorrectAnswerFilePicker(),
                    ],
                    if (_selectedAnswerType == 'MCQ') ...[
                      const SizedBox(height: 24),
                      Text(
                        'الخيارات',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Display existing options with edit/delete/toggle functionality
                      ...List.generate(_tempOptions.length, (index) {
                        final opt = _tempOptions[index];
                        final isBeingEdited = _editingOptionIndex == index;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isBeingEdited
                                ? AppColors.primary.withOpacity(0.1)
                                : Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBeingEdited
                                  ? AppColors.primary
                                  : opt['isCorrect']
                                  ? AppColors.success.withOpacity(0.5)
                                  : AppColors.glassBorder,
                              width: isBeingEdited ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Tap to toggle correct status
                              InkWell(
                                onTap: () => _toggleOptionCorrect(index),
                                child: Icon(
                                  opt['isCorrect']
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: opt['isCorrect']
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  opt['content'],
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                    fontWeight: isBeingEdited
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              // Edit button
                              IconButton(
                                icon: Icon(
                                  isBeingEdited ? Icons.check : Icons.edit,
                                  size: 18,
                                  color: isBeingEdited
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                                tooltip: isBeingEdited ? 'تم التحرير' : 'تعديل',
                                onPressed: () {
                                  if (isBeingEdited) {
                                    _cancelEditingOption();
                                  } else {
                                    _startEditingOption(index);
                                  }
                                },
                              ),
                              // Delete button
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                tooltip: 'حذف',
                                onPressed: () {
                                  if (_editingOptionIndex == index) {
                                    _cancelEditingOption();
                                  }
                                  setState(() => _tempOptions.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      // Input row for adding/editing options
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _editingOptionIndex != null
                              ? AppColors.primary.withOpacity(0.05)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: _editingOptionIndex != null
                              ? Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_editingOptionIndex != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'تعديل الخيار ${_editingOptionIndex! + 1}',
                                      style: GoogleFonts.inter(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _cancelEditingOption,
                                      child: const Text(
                                        'إلغاء',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _optionController,
                                    label: _editingOptionIndex != null
                                        ? 'تعديل محتوى الخيار'
                                        : 'محتوى الخيار الجديد',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    Text(
                                      'صحيح',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                    Checkbox(
                                      value: _optionIsCorrect,
                                      activeColor: AppColors.success,
                                      onChanged: (val) => setState(
                                        () => _optionIsCorrect = val!,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: _addTempOption,
                                  icon: Icon(
                                    _editingOptionIndex != null
                                        ? Icons.save
                                        : Icons.add_circle,
                                    color: _editingOptionIndex != null
                                        ? AppColors.success
                                        : AppColors.primary,
                                    size: 32,
                                  ),
                                  tooltip: _editingOptionIndex != null
                                      ? 'حفظ التعديل'
                                      : 'إضافة خيار',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isEditing
                                        ? Icons.save_rounded
                                        : Icons.add_rounded,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEditing
                                        ? 'تحديث السؤال'
                                        : 'إضافة السؤال إلى الاختبار',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Existing Questions List
            if (_existingQuestions.isNotEmpty) ...[
              Text(
                'الأسئلة الموجودة (${_existingQuestions.length})',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _existingQuestions.length,
                itemBuilder: (context, index) {
                  final q = _existingQuestions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (q.questionType == 'Image' &&
                                  q.content.isNotEmpty &&
                                  (q.content.startsWith('http') ||
                                      q.content.startsWith('/')))
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        insetPadding: EdgeInsets.zero,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  Navigator.pop(context),
                                              child: Container(
                                                  color: Colors.black87),
                                            ),
                                            InteractiveViewer(
                                              panEnabled: true,
                                              minScale: 0.5,
                                              maxScale: 4.0,
                                              child: Center(
                                                child: Image.network(
                                                  q.content,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.white,
                                                    size: 64,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 40,
                                              right: 20,
                                              child: IconButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                icon: Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      q.content,
                                      height: 60,
                                      width: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        height: 60,
                                        width: 80,
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.error.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: AppColors.error,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  q.content,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                '${_translateQuestionType(q.questionType)} • ${_translateAnswerType(q.answerType)} • الدرجة: ${q.score}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Show correct answer based on answer type
                        // For TextAnswer: show text icon and display text answer
                        if (q.answerType == 'TextAnswer' &&
                            q.correctAnswer != null &&
                            q.correctAnswer!.isNotEmpty &&
                            q.correctAnswer != '0')
                          IconButton(
                            icon: const Icon(
                              Icons.text_snippet_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                            tooltip: 'الإجابة الصحيحة',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'الإجابة الصحيحة',
                                        style: GoogleFonts.outfit(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.success.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      q.correctAnswer!,
                                      style: GoogleFonts.inter(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('إغلاق'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        // For ImageAnswer: show image icon and display image
                        if (q.answerType == 'ImageAnswer' &&
                            ((q.correctAnswerImageUrl != null &&
                                    q.correctAnswerImageUrl!.isNotEmpty) ||
                                (q.correctAnswer != null &&
                                    q.correctAnswer!.isNotEmpty &&
                                    q.correctAnswer != '0')))
                          IconButton(
                            icon: const Icon(
                              Icons.image_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                            tooltip: 'نموذج الإجابة',
                            onPressed: () {
                              // Use correctAnswerImageUrl if available, otherwise fallback to correctAnswer
                              final imageUrl =
                                  q.correctAnswerImageUrl ?? q.correctAnswer;
                              if (imageUrl == null ||
                                  imageUrl.isEmpty ||
                                  imageUrl == '0') {
                                return;
                              }

                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: EdgeInsets.zero,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(color: Colors.black87),
                                      ),
                                      InteractiveViewer(
                                        panEnabled: true,
                                        minScale: 0.5,
                                        maxScale: 4.0,
                                        child: Center(
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.white,
                                                      size: 64,
                                                    ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 40,
                                        right: 20,
                                        child: IconButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: AppColors.primary,
                          ),
                          tooltip: 'تعديل',
                          onPressed: () => _startEditing(q),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: AppColors.error,
                          ),
                          tooltip: 'حذف',
                          onPressed: () => _deleteQuestion(q.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            if (_addedQuestions.isNotEmpty) ...[
              Text(
                'الأسئلة المضافة حديثاً (${_addedQuestions.length})',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addedQuestions.length,
                itemBuilder: (context, index) {
                  final q = _addedQuestions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.success.withOpacity(0.1),
                          child: const Icon(
                            Icons.check,
                            color: AppColors.success,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.content,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_translateQuestionType(q.questionType)} • ${_translateAnswerType(q.answerType)} • الدرجة: ${q.score}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _finishExamCreation,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'إنهاء إنشاء الاختبار',
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool isNumeric = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
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
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Theme.of(context).cardColor,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
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
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      items: items.entries.map((entry) {
        return DropdownMenuItem(value: entry.key, child: Text(entry.value));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Future<XFile?> _cropImage(XFile imageFile) async {
    // Navigate to custom crop screen
    final croppedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomImageCropScreen(imagePath: imageFile.path),
      ),
    );

    if (croppedPath != null) {
      return XFile(croppedPath);
    }
    return null;
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: () async {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          final croppedImage = await _cropImage(image);
          if (croppedImage != null) {
            setState(() {
              _selectedFile = croppedImage;
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedFile != null
              ? AppColors.success.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedFile != null
                ? AppColors.success.withOpacity(0.3)
                : AppColors.primary.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selectedFile != null
                  ? Icons.check_circle_rounded
                  : Icons.image_rounded,
              color: _selectedFile != null
                  ? AppColors.success
                  : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedFile != null
                    ? _selectedFile!.name
                    : 'إضافة صورة للسؤال (اختياري)',
                style: TextStyle(
                  color: _selectedFile != null
                      ? AppColors.success
                      : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectAnswerFilePicker() {
    return InkWell(
      onTap: () async {
        final ImagePicker picker = ImagePicker();
        // Allow picking image for model answer
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          final croppedImage = await _cropImage(image);
          if (croppedImage != null) {
            setState(() {
              _selectedCorrectAnswerFile = croppedImage;
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedCorrectAnswerFile != null
              ? AppColors.success.withOpacity(0.1)
              : Colors.orange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedCorrectAnswerFile != null
                ? AppColors.success.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selectedCorrectAnswerFile != null
                  ? Icons.check_circle_rounded
                  : Icons.file_present_rounded,
              color: _selectedCorrectAnswerFile != null
                  ? AppColors.success
                  : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCorrectAnswerFile != null
                    ? _selectedCorrectAnswerFile!.name
                    : 'إرفاق ملف الإجابة النموذجية (اختياري)',
                style: TextStyle(
                  color: _selectedCorrectAnswerFile != null
                      ? AppColors.success
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_selectedCorrectAnswerFile != null)
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.error),
                onPressed: () {
                  setState(() {
                    _selectedCorrectAnswerFile = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  String _translateQuestionType(String type) {
    switch (type) {
      case 'Text':
        return 'نص';
      case 'Image':
        return 'صورة';
      default:
        return type;
    }
  }

  String _translateAnswerType(String type) {
    switch (type) {
      case 'MCQ':
        return 'اختيار من متعدد';
      case 'ImageAnswer':
        return 'إجابة بصورة';
      case 'TextAnswer':
        return 'إجابة نصية';
      default:
        return type;
    }
  }
}
