import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/course_models.dart';
import 'package:edu_platform_app/data/services/course_service.dart';
import 'package:edu_platform_app/data/services/teacher_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edu_platform_app/core/utils/score_utils.dart';
import 'package:edu_platform_app/presentation/screens/teacher/image_editor_screen.dart';
import 'package:edu_platform_app/presentation/screens/teacher/add_exam_questions_screen.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

class StudentExamScreen extends StatefulWidget {
  final int lectureId;
  final int? examId;
  final String lectureTitle;
  final bool isTeacher;
  final int? viewingStudentId;
  final String? viewingStudentName;
  final bool isGraded;

  const StudentExamScreen({
    super.key,
    required this.lectureId,
    this.examId,
    required this.lectureTitle,
    this.isTeacher = false,
    this.viewingStudentId,
    this.viewingStudentName,
    this.isGraded = false,
  });

  @override
  State<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends State<StudentExamScreen> {
  final _courseService = CourseService();
  final _teacherService = TeacherService();
  final _tokenService = TokenService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  Exam? _exam;
  String? _error;
  String? _gradedByName;
  bool _showStartScreen = false;

  // State for answers
  // MCQ: QuestionID -> List of OptionIDs
  final Map<int, List<int>> _selectedOptions = {};
  // Text: QuestionID -> Text Answer
  final Map<int, String> _textAnswers = {};
  // Image Answer: QuestionId -> Local File Path
  final Map<int, String> _localImagePaths = {};
  // Image Answer: QuestionId -> Server URL (Uploaded)
  final Map<int, String> _uploadedImageUrls = {};
  // Uploading status: QuestionId -> bool
  final Map<int, bool> _isUploadingImage = {};

  final ScrollController _scrollController = ScrollController();

  // Detailed Results: QuestionID -> Result object
  final Map<int, StudentAnswerResult> _studentAnswerResults = {};

  // Teacher Grading State: QuestionID -> Score/Feedback
  final Map<int, double> _teacherPoints = {};
  final Map<int, String> _teacherFeedback = {};
  double _bonusPoints = 0.0; // extra bonus score added by teacher

  bool _isAlreadySubmitted = false;
  bool _isGraded = false;
  double? _savedScore;

  // Timer & Deadline
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isExpired = false;
  bool _hasTimer = false;
  bool _isReviewing = false;
  int? _studentExamResultId;
  bool _isAssistant = false;
  DateTime? _effectiveDeadline;

  @override
  void initState() {
    super.initState();
    _fetchExam();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final role = await _tokenService.getRole();
    if (mounted) {
      setState(() {
        _isAssistant = role == 'Assistant';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _getErrorMessage(String originalMessage, [int? statusCode]) {
    final lower = originalMessage.toLowerCase();
    if (statusCode == 500 ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('network')) {
      return 'يوجد مشكلة في الانترنت او الخادم، يرجى المحاولة لاحقاً';
    }
    return originalMessage;
  }

  Future<void> _fetchExam() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final effectiveStudentId =
        widget.viewingStudentId ?? await _tokenService.getUserId();

    Exam? fetchedExam;
    bool success = false;

    // 1. Try fetching specific exam by ID
    if (widget.examId != null) {
      final response = await _courseService.getExamById(widget.examId!);
      if (response.succeeded && response.data != null) {
        fetchedExam = response.data;
        success = true;
      } else if (response.message.isNotEmpty) {
        _error = _getErrorMessage(response.message, response.statusCode);
      }
    }

    // 2. Fallback to lecture exams if no specific ID or fetched successfully
    // Only fallback if check failed and we don't have a specific error, or if ID wasn't provided
    if (success && fetchedExam != null) {
      print('🔍 DEBUG: Fetched Exam ID: ${fetchedExam.id}');
      for (var q in fetchedExam.questions) {
        print('🔍 DEBUG: Question[${q.id}] Content: "${q.content}"');
        print(
          '🔍 DEBUG: Question[${q.id}] CorrectAnswer: "${q.correctAnswer}"',
        );
        print('🔍 DEBUG: Question[${q.id}] Options Count: ${q.options.length}');
      }
    }

    // Try fetching by lectureId if examId failed
    if (!success && widget.examId == null) {
      final response = await _courseService.getExamByLectureId(
        widget.lectureId,
      );
      if (response.succeeded &&
          response.data != null &&
          response.data!.isNotEmpty) {
        fetchedExam = response.data!.first;
        success = true;
      } else if (!response.succeeded && response.message.isNotEmpty) {
        _error = _getErrorMessage(response.message, response.statusCode);
      }
    }

    if (success &&
        fetchedExam != null &&
        fetchedExam.isRandomized &&
        !widget.isTeacher) {
      print('🔀 Exam is randomized. Shuffling questions...');
      fetchedExam.questions.shuffle();
    }

    bool submitted = false;
    double? score;

    if (success && fetchedExam != null && effectiveStudentId != null) {
      final exam = fetchedExam;
      final prefs = await SharedPreferences.getInstance();

      if (!widget.isTeacher || widget.viewingStudentId != null) {
        // 1. Check status from Server
        // Check local storage for start time
        final startTimeKey = 'exam_${effectiveStudentId}_${exam.id}_startTime';
        final bool localStartExists = prefs.getString(startTimeKey) != null;

        final resultResponse = await _courseService.getStudentExamResult(
          exam.id,
          studentId: effectiveStudentId,
        );

        if (resultResponse.succeeded && resultResponse.data != null) {
          final result = resultResponse.data!;
          _studentExamResultId = result.studentExamResultId;
          _gradedByName = result.gradedByName;
          _isGraded = result.isGraded;
          print('🔍 DEBUG: isGraded = $_isGraded');

          // Consider submitted if:
          // 1. Explicitly finished
          // 2. Has a submission timestamp
          // 3. Has recorded answers (fallback)
          submitted = result.isFinished ||
              result.submittedAt != null ||
              result.studentAnswers.isNotEmpty;

          if (submitted) {
            score = result.totalScore;

            // Populate answers for Review Mode
            for (var ans in result.studentAnswers) {
              _studentAnswerResults[ans.questionId] = ans;

              if (ans.textAnswer != null && ans.textAnswer!.isNotEmpty) {
                _textAnswers[ans.questionId] = ans.textAnswer!;
              }

              // Map selected options
              // First try the selectedOptions list from API
              if (ans.selectedOptions.isNotEmpty) {
                final ids = <int>[];
                for (var item in ans.selectedOptions) {
                  if (item is int) {
                    ids.add(item);
                  } else if (item is Map && item.containsKey('optionId')) {
                    ids.add(item['optionId']);
                  } else if (item is String) {
                    ids.add(int.tryParse(item) ?? 0);
                  }
                }

                if (ids.where((id) => id != 0).isNotEmpty) {
                  _selectedOptions[ans.questionId] =
                      ids.where((id) => id != 0).toList();
                }
              } else {
                // Fallback: Check inside questionOptions for isSelected
                final selectedIds = ans.questionOptions
                    .where((opt) => opt.isSelected)
                    .map((opt) => opt.optionId)
                    .toList();
                if (selectedIds.isNotEmpty) {
                  _selectedOptions[ans.questionId] = selectedIds;
                }
              }

              // Initialize Teacher Grading State
              if (widget.isTeacher && widget.viewingStudentId != null) {
                if (ans.pointsEarned != null) {
                  _teacherPoints[ans.questionId] = ans.pointsEarned!;
                }
                if (ans.feedback != null) {
                  _teacherFeedback[ans.questionId] = ans.feedback!;
                }
              }
            }
          }
        } else {
          // Check for network errors first
          if (!resultResponse.succeeded && resultResponse.statusCode != 404) {
            final msg = _getErrorMessage(
                resultResponse.message, resultResponse.statusCode);
            // If message was modified, it's a network error
            if (msg != resultResponse.message) {
              _error = msg;
            }
          }

          // If 404 or just failed...
          if (resultResponse.statusCode == 404 ||
              (resultResponse.succeeded && resultResponse.data == null)) {
            if (localStartExists) {
              _showStartScreen = false;
            } else {
              _showStartScreen = true;
              print(
                '🆕 Exam session not found & no local start. Showing start screen.',
              );
            }
          }

          // IMPORTANT: If 404 (never attempted), don't check deadline
          // Only check deadline if student has started but not submitted
          // This allows students with exceptions to start the exam even after deadline
        }

        // If not submitted AND has attempted the exam (not 404), check local conditions
        // If 404, skip deadline check entirely (allow fresh start)
        final hasAttemptedExam =
            (resultResponse.succeeded && resultResponse.data != null) ||
                localStartExists;

        print(
          '🔍 Exam status: submitted=$submitted, hasAttemptedExam=$hasAttemptedExam, resultSucceeded=${resultResponse.succeeded}, hasData=${resultResponse.data != null}',
        );

        // Check Deadline for ALL students (not just those who attempted)
        if (!submitted) {
          // Check Deadline - compare exact datetime
          if (exam.deadline != null) {
            final now = DateTime.now();
            final deadline = exam.deadline!;
            _effectiveDeadline = deadline;

            // Always check for exceptions/access status if there's a deadline
            // to ensure we have the correct effective deadline (original or extended)
            final accessResponse = await _courseService.checkExamAccess(
              examId: exam.id,
              studentId: effectiveStudentId,
            );

            if (accessResponse.succeeded && accessResponse.data != null) {
              final access = accessResponse.data!;
              _effectiveDeadline =
                  access.extendedDeadline ?? access.deadline ?? exam.deadline;

              final nowMinute =
                  DateTime(now.year, now.month, now.day, now.hour, now.minute);
              final effectiveDeadlineMinute = DateTime(
                  _effectiveDeadline!.year,
                  _effectiveDeadline!.month,
                  _effectiveDeadline!.day,
                  _effectiveDeadline!.hour,
                  _effectiveDeadline!.minute);

              if (nowMinute.isAfter(effectiveDeadlineMinute)) {
                if (access.hasException) {
                  print(
                      '✅ Student has exception. Access granted until ${_formatDeadline(_effectiveDeadline!)}');
                } else {
                  print('❌ No exception. Access denied.');
                  if (mounted) {
                    setState(() {
                      _isExpired = true;
                    });
                  }
                }
              }
            } else {
              // API failed - fallback to checking original deadline
              final nowMinute =
                  DateTime(now.year, now.month, now.day, now.hour, now.minute);
              final deadlineMinute = DateTime(deadline.year, deadline.month,
                  deadline.day, deadline.hour, deadline.minute);

              if (nowMinute.isAfter(deadlineMinute)) {
                print(
                    '❌ Failed to check access. Blocking access based on original deadline.');
                if (mounted) {
                  setState(() {
                    _isExpired = true;
                  });
                }
              }
            }
          }

          // Handle Duration / Timer (only for students who have attempted)
          if (hasAttemptedExam) {
            final isAssignment = exam.type == 'Assignment';
            if (!isAssignment && exam.durationInMinutes > 0 && !_isExpired) {
              final startTimeKey =
                  'exam_${effectiveStudentId}_${exam.id}_startTime';
              String? startTimeStr = prefs.getString(startTimeKey);
              DateTime startTime;

              if (startTimeStr == null) {
                startTime = DateTime.now();
                await prefs.setString(
                  startTimeKey,
                  startTime.toIso8601String(),
                );
              } else {
                startTime = DateTime.parse(startTimeStr);
              }

              final elapsed = DateTime.now().difference(startTime);
              final totalDuration = Duration(minutes: exam.durationInMinutes);
              final remaining = totalDuration - elapsed;

              if (remaining.isNegative) {
                _isExpired = true; // Timer ran out while away
              } else {
                _remainingTime = remaining;
                _hasTimer = true;
                _startTimer();
              }
            }
          }
        }
      }
    }

    // Finalize state
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success && fetchedExam != null) {
          _exam = fetchedExam;
          // Teachers viewing their own test (preview) see no submission.
          // Teachers viewing a student's submission see it as submitted/reviewing.
          _isAlreadySubmitted =
              (widget.isTeacher && widget.viewingStudentId == null)
                  ? false
                  : submitted;
          _isReviewing = (widget.viewingStudentId != null && submitted);
          _savedScore = score;
        } else {
          _error = _error ?? 'فشل تحميل الاختبار';
        }
      });
    }
  }

  Future<void> _startExamSession() async {
    if (_exam == null) return;

    setState(() => _isLoading = true);

    try {
      final effectiveStudentId =
          widget.viewingStudentId ?? await _tokenService.getUserId();

      if (effectiveStudentId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // No API call for starting exam. Just local state.
      _showStartScreen = false;

      // Initialize Timer for Fresh Start
      if (_exam!.durationInMinutes > 0) {
        final prefs = await SharedPreferences.getInstance();
        final startTimeKey =
            'exam_${effectiveStudentId}_${_exam!.id}_startTime';

        // Ensure we don't overwrite if likely exists (e.g. user re-entered quickly)
        if (prefs.getString(startTimeKey) == null) {
          await prefs.setString(startTimeKey, DateTime.now().toIso8601String());
        }

        _remainingTime = Duration(minutes: _exam!.durationInMinutes);
        _hasTimer = true;
        _startTimer();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error starting exam: $e');
    }
  }

  void _showStartConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('هل أنت متأكد من بدء الاختبار؟'),
        content: const Text('عند البدء، سيتم احتساب الوقت ولن يمكنك التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startExamSession();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'بدء الاختبار',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              _exam?.title ?? 'الاختبار',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'مدة الاختبار: ${_exam?.durationInMinutes ?? 0} دقيقة',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 48),
            if (_isExpired)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'عذراً، انتهى وقت الاختبار',
                      style: GoogleFonts.inter(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _showStartConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'بدء الاختبار',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getPendingCount() {
    int count = 0;
    if (_exam == null) return 0;
    for (var q in _exam!.questions) {
      final res = _studentAnswerResults[q.id];
      if (res != null) {
        // A question needs grading if it's a text/image answer, or if it's an MCQ
        // but the API returned null for pointsEarned (which shouldn't happen for MCQs
        // but as a safeguard) AND it's not an MCQ.
        // More accurately, it needs grading if pointsEarned is null AND it's a text/image answer.
        // For MCQs, pointsEarned should always be set by the server.
        final bool isManualGradingType =
            q.answerType == 'TextAnswer' || q.answerType == 'ImageAnswer';
        if (res.pointsEarned == null && isManualGradingType) {
          count++;
        }
      }
    }
    return count;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 🚨 CRITICAL: Check absolute deadline even if timer has time left
      if (_effectiveDeadline != null) {
        final now = DateTime.now();
        if (now.isAfter(_effectiveDeadline!)) {
          timer.cancel();
          _handleTimeUp(reason: 'انتهى الموعد النهائي للاختبار (Deadline)!');
          return;
        }
      }

      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _handleTimeUp();
      } else {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      }
    });
  }

  void _handleTimeUp({String? reason}) {
    _timer?.cancel();

    if (_isAlreadySubmitted || _isSubmitting) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason ?? 'انتهى الوقت! جاري تسليم الاختبار...'),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 3),
      ),
    );

    _submitExam();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours > 0 ? '${duration.inHours}:' : '';
    return '$hours$minutes:$seconds';
  }

  String _formatDeadline(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.day.toString().padLeft(2, '0')} - '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showExamSettings() {
    if (_exam == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'إعدادات الاختبار',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingRow(
                icon: Icons.title_rounded,
                label: 'العنوان',
                value: _exam!.title,
              ),
              Divider(color: AppColors.glassBorder),
              _buildSettingRow(
                icon: Icons.category_outlined,
                label: 'النوع',
                value: _exam!.type == 'Assignment' ? 'واجب' : 'اختبار',
              ),
              Divider(color: AppColors.glassBorder),
              _buildSettingRow(
                icon: Icons.timer_outlined,
                label: 'المدة',
                value: _exam!.durationInMinutes > 0
                    ? '${_exam!.durationInMinutes} دقيقة'
                    : 'غير محدد',
              ),
              Divider(color: AppColors.glassBorder),
              _buildSettingRow(
                icon: Icons.event_outlined,
                label: 'الموعد النهائي',
                value: _exam!.deadline != null
                    ? _formatDeadline(_exam!.deadline!)
                    : 'غير محدد',
              ),
              Divider(color: AppColors.glassBorder),
              _buildSettingRow(
                icon: Icons.quiz_outlined,
                label: 'عدد الأسئلة',
                value: '${_exam!.questions.length}',
              ),
              Divider(color: AppColors.glassBorder),
              _buildSettingRow(
                icon: Icons.grade_outlined,
                label: 'مجموع الدرجات',
                value:
                    '${_exam!.questions.fold<int>(0, (sum, q) => sum + q.score)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTeacherFooter = !_isLoading &&
        _exam != null &&
        _isReviewing &&
        widget.isTeacher &&
        widget.viewingStudentId != null;

    return Scaffold(
      bottomNavigationBar:
          showTeacherFooter ? _buildTeacherGradingFooter() : null,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.viewingStudentName != null
                  ? 'مراجعة: ${widget.viewingStudentName}'
                  : 'الاختبار: ${widget.lectureTitle}',
              style: GoogleFonts.outfit(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 16,
              ),
            ),
            if (_hasTimer && !_isAlreadySubmitted && !_isLoading && !_isExpired)
              Text(
                'الوقت المتبقي: ${_formatDuration(_remainingTime)}',
                style: GoogleFonts.inter(
                  color: _remainingTime.inMinutes < 5
                      ? AppColors.error
                      : AppColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).cardColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Show edit questions and settings buttons for teachers and assistants
          if ((widget.isTeacher || _isAssistant) &&
              _exam != null &&
              !_isLoading &&
              widget.viewingStudentId == null) ...[
            // Edit Questions Button
            IconButton(
              icon: const Icon(
                Icons.edit_note_rounded,
                color: AppColors.primary,
              ),
              tooltip: 'تعديل الأسئلة',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddExamQuestionsScreen(examId: _exam!.id),
                  ),
                ).then((_) => _fetchExam()); // Refresh after editing
              },
            ),
            // Settings Button
            IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.primary,
              ),
              tooltip: 'إعدادات الاختبار',
              onPressed: () => _showExamSettings(),
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.inter(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'حاول مرة أخرى',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_exam == null) {
      return Center(
        child: Text(
          'لم يتم العثور على اختبار.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      );
    }

    if (_exam!.questions.isEmpty) {
      return Center(
        child: Text(
          'لا يوجد أسئلة',
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (_showStartScreen && !_isAlreadySubmitted && !_isReviewing) {
      return _buildStartScreen();
    }

    if (_isAlreadySubmitted && !_isReviewing) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon with Glow
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 72,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'تم الانتهاء بنجاح',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'إليك نتيجة أدائك في هذا الاختبار',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),

              if (_gradedByName != null && _gradedByName!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تم التصحيح بواسطة: $_gradedByName',
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),

              if (_savedScore != null)
                Builder(
                  builder: (context) {
                    double mcqScore = 0;
                    int mcqMax = 0;
                    double essayScore = 0;
                    int essayMax = 0;
                    bool hasPending = false;
                    bool hasEssays = false;

                    if (_exam != null) {
                      for (var q in _exam!.questions) {
                        final bool isManualGradingType =
                            q.answerType == 'TextAnswer' ||
                                q.answerType == 'ImageAnswer';

                        final res = _studentAnswerResults[q.id];
                        if (isManualGradingType) {
                          hasEssays = true;
                          final qMax = (res != null && res.maxScore > 0)
                              ? res.maxScore
                              : q.score;
                          essayMax += qMax;
                          if (res != null) {
                            if (res.pointsEarned != null) {
                              essayScore += res.pointsEarned!;
                            } else {
                              hasPending = true;
                            }
                          }
                        } else {
                          final qMax = (res != null && res.maxScore > 0)
                              ? res.maxScore
                              : q.score;
                          mcqMax += qMax;
                          if (res != null) {
                            if (res.pointsEarned != null) {
                              mcqScore += res.pointsEarned!;
                            } else {
                              final hasCorrect = res.questionOptions.any(
                                    (o) => o.isSelected && o.isCorrect,
                                  ) ||
                                  res.selectedOptions.any(
                                    (o) => (o is Map && o['isCorrect'] == true),
                                  );
                              if (hasCorrect) mcqScore += qMax;
                            }
                          }
                        }
                      }
                    }

                    final totalScore = _exam?.questions.fold<int>(
                          0,
                          (sum, q) {
                            final res = _studentAnswerResults[q.id];
                            final qMax = (res != null && res.maxScore > 0)
                                ? res.maxScore
                                : q.score;
                            return sum + qMax;
                          },
                        ) ??
                        0;
                    final score = _savedScore!;
                    final percentage =
                        totalScore > 0 ? score / totalScore : 0.0;
                    final isPassing = percentage >= 0.5;

                    return Column(
                      children: [
                        // Circular Score Indicator
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              height: 220,
                              child: CircularProgressIndicator(
                                value: percentage,
                                strokeWidth: 15,
                                backgroundColor: AppColors.surfaceLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isPassing
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  score.toStringAsFixed(1),
                                  style: GoogleFonts.outfit(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  height: 2,
                                  width: 50,
                                  color: Colors.white12,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                Text(
                                  '/ $totalScore',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Pending grading message
                        if (hasPending)
                          Container(
                            margin: const EdgeInsets.only(top: 32),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.warning.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    'في انتظار تصحيح الأسئلة المقالية',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 48),

                        // Breakdown Cards
                        if (mcqMax > 0 || hasEssays)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Column(
                              children: [
                                if (mcqMax > 0)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check_box_outlined,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          'الاختيارات',
                                          style: GoogleFonts.inter(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${mcqScore.toStringAsFixed(1)} / $mcqMax',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (mcqMax > 0 && hasEssays)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                if (hasEssays)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit_note_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          'المقال',
                                          style: GoogleFonts.inter(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (hasPending)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppColors.warning
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            'معلق',
                                            style: GoogleFonts.inter(
                                              color: AppColors.warning,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        Text(
                                          '${essayScore.toStringAsFixed(1)} / $essayMax',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 48),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isReviewing = true;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.glassBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'مراجعة الإجابات',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'خروج',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_isExpired) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.timer_off_outlined,
              color: AppColors.error,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              'انتهت صلاحية الاختبار',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لقد مر الموعد النهائي أو انتهى الوقت.',
              style: GoogleFonts.inter(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'العودة للدورة',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Main content (Exam Questions)
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          // Add 1 to itemCount if we need to show the submit button
          itemCount: (!widget.isTeacher && !_isAlreadySubmitted)
              ? _exam!.questions.length + 1
              : _exam!.questions.length,
          itemBuilder: (context, index) {
            // Check if this is the last item and we need to show the submit button
            if ((!widget.isTeacher && !_isAlreadySubmitted) &&
                index == _exam!.questions.length) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitExam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'تسليم الاختبار',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              );
            }

            // Otherwise return the question card
            final question = _exam!.questions[index];
            return _buildQuestionCard(question, index + 1);
          },
        ),

        // 2. Review Mode Footer (For Student)
        if (_isReviewing && !widget.isTeacher)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'وضع المراجعة (للقراءة فقط)',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _submitExam() async {
    if (_exam == null) return;

    // Validation? Checking if all mandatory questions answered?
    // For now, allow partial submission or just submit what we have.

    setState(() => _isSubmitting = true);

    try {
      final effectiveStudentId =
          widget.viewingStudentId ?? await _tokenService.getUserId();
      if (effectiveStudentId == null) {
        throw Exception('User ID not found');
      }

      final answers = <ExamAnswerRequest>[];

      for (var question in _exam!.questions) {
        if (question.answerType == 'TextAnswer') {
          // For text answer
          final text = _textAnswers[question.id];
          if (text != null && text.isNotEmpty) {
            answers.add(
              ExamAnswerRequest(questionId: question.id, textAnswer: text),
            );
          }
        } else if (question.answerType == 'ImageAnswer') {
          final url = _uploadedImageUrls[question.id];
          if (url != null) {
            answers.add(
              ExamAnswerRequest(questionId: question.id, imageAnswerUrl: url),
            );
          }
        } else {
          // MCQ
          final selected = _selectedOptions[question.id] ?? [];
          if (selected.isNotEmpty) {
            answers.add(
              ExamAnswerRequest(
                questionId: question.id,
                selectedOptionIds: selected,
              ),
            );
          }
        }
      }

      final request = ExamSubmissionRequest(
        examId: _exam!.id,
        studentId: effectiveStudentId,
        answers: answers,
      );

      final response = await _courseService.submitExam(request);

      if (response.succeeded && response.data != null) {
        // Save submission status
        final prefs = await SharedPreferences.getInstance();
        final key = 'exam_${effectiveStudentId}_${_exam!.id}_submitted';
        await prefs.setBool(key, true);
        await prefs.setDouble(
          'exam_${effectiveStudentId}_${_exam!.id}_score',
          response.data!,
        );

        // Fetch exam result to get detailed breakdown (which answers were correct/incorrect)
        // This populates _studentAnswerResults
        await _fetchExam();

        // Note: _fetchExam sets _isAlreadySubmitted to true and updates _savedScore
        // so we don't strictly need to set them here, but for safety in case fetch fails:
        if (mounted && !_isAlreadySubmitted) {
          setState(() {
            _isAlreadySubmitted = true;
            _savedScore = response.data!;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(_getErrorMessage(response.message, response.statusCode)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التسليم: ${_getErrorMessage(e.toString())}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildQuestionCard(Question question, int index) {
    final res = _studentAnswerResults[question.id];
    final bool isManualGradingType = question.answerType == 'TextAnswer' ||
        question.answerType == 'ImageAnswer';
    final bool needsGrading = widget.isTeacher &&
        res != null &&
        res.pointsEarned == null &&
        isManualGradingType;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: needsGrading ? AppColors.warning : AppColors.glassBorder,
          width: needsGrading ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (needsGrading)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pending_rounded,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '⚠️ يحتاج مراجعة وتصحيح',
                      style: GoogleFonts.inter(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            // Review Score / Status (Shows for both Student & Teacher)
            if (_isReviewing && _studentAnswerResults.containsKey(question.id))
              Builder(
                builder: (context) {
                  final result = _studentAnswerResults[question.id]!;
                  final isManualGradingType =
                      question.answerType == 'TextAnswer' ||
                          question.answerType == 'ImageAnswer';

                  bool isCorrect = result.isCorrect;
                  double? earned = result.pointsEarned;

                  // API Quirk Handling: If MCQ and pointsEarned is null, check selected options
                  if (earned == null && !isManualGradingType) {
                    // Check if any selected option is correct
                    final hasCorrectSelection = result.selectedOptions.any((o) {
                          if (o is Map && o['isCorrect'] == true) return true;
                          // If IDs were passed, we'd need to check against question options
                          return false;
                        }) ||
                        result.questionOptions.any(
                          (o) => o.isSelected && o.isCorrect,
                        );

                    if (hasCorrectSelection) {
                      isCorrect = true;
                      earned = question.score.toDouble();
                    } else {
                      earned = 0.0;
                    }
                  }

                  // If still null and text/image -> Pending
                  if (earned == null && isManualGradingType) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pending_actions,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'بانتظار التصحيح / ${formatScore(result.maxScore > 0 ? result.maxScore : question.score)}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  Color statusColor =
                      isCorrect ? AppColors.success : AppColors.error;
                  IconData statusIcon =
                      isCorrect ? Icons.check_circle : Icons.cancel;

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'الدرجة: ${formatScore(earned ?? 0)} / ${formatScore(result.maxScore > 0 ? result.maxScore : question.score)}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Feedback and Grader Name (For both students and teachers when reviewing)
            if (_isReviewing && _studentAnswerResults.containsKey(question.id))
              Builder(
                builder: (context) {
                  final result = _studentAnswerResults[question.id]!;

                  // Only show if feedback exists or gradedByName exists
                  if (result.feedback == null && result.gradedByName == null) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (result.gradedByName != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: AppColors.primary.withOpacity(0.7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'تم التصحيح بواسطة: ${result.gradedByName}',
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
                          if (result.feedback != null)
                            const SizedBox(height: 8),
                        ],
                        if (result.feedback != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.comment_rounded,
                                size: 16,
                                color: AppColors.primary.withOpacity(0.7),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ملاحظات المصحح:',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      result.feedback!,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

            // Question Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'السؤال $index',
                  style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${question.score} درجات',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question Content (Text or Image)
            if (question.questionType == 'Image')
              GestureDetector(
                onTap: () {
                  // Open fullscreen image viewer
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.zero,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Dark background
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(color: Colors.black87),
                          ),
                          // Zoomable image
                          InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.network(
                                question.content,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                    size: 64,
                                  );
                                },
                              ),
                            ),
                          ),
                          // Close button
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
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          // Hint text
                          Positioned(
                            bottom: 40,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'قرص للتكبير • انقر في الخارج للإغلاق',
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        question.content,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            width: double.infinity,
                            color: AppColors.surfaceLight,
                            child: Icon(
                              Icons.broken_image,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          );
                        },
                      ),
                    ),
                    // Zoom icon overlay
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                question.content,
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

            const SizedBox(height: 20),

            const SizedBox(height: 20),

            // Answer Input
            if (question.answerType == 'TextAnswer') ...[
              TextFormField(
                initialValue: _textAnswers[question.id] ?? '',
                readOnly: _isAlreadySubmitted,
                onChanged: (val) {
                  if (!_isAlreadySubmitted) {
                    _textAnswers[question.id] = val;
                  }
                },
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'اكتب إجابتك هنا...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceLight.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.glassBorder),
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
            ] else if (question.answerType == 'ImageAnswer') ...[
              _buildImageAnswerInput(question),
            ] else
              // MCQ Options
              ...question.options.map((option) {
                // Correctly determine isCorrect for Review Mode
                bool isCorrect = option.isCorrect;

                if (_isReviewing &&
                    _studentAnswerResults.containsKey(question.id)) {
                  final resultOptions =
                      _studentAnswerResults[question.id]!.questionOptions;
                  try {
                    final resultOption = resultOptions.firstWhere(
                      (o) => o.optionId == option.id,
                    );
                    isCorrect = resultOption.isCorrect;
                  } catch (_) {
                    // Option not found in results, fallback to default
                  }
                }

                final isSelected =
                    _selectedOptions[question.id]?.contains(option.id) ?? false;

                // Show correctness if teacher OR (student is reviewing AND exam is graded)
                bool canShowAnswers = widget.isTeacher ||
                    (_isReviewing && _isAlreadySubmitted && _isGraded);

                final showCorrect = canShowAnswers && isCorrect;
                final showWrong = canShowAnswers && isSelected && !isCorrect;

                Color borderColor = AppColors.glassBorder;
                Color backgroundColor = AppColors.surfaceLight.withOpacity(0.5);
                Color textColor = AppColors.textPrimary;

                if (showCorrect) {
                  borderColor = AppColors.success;
                  backgroundColor = AppColors.success.withOpacity(0.1);
                  textColor = AppColors.success;
                } else if (showWrong) {
                  borderColor = AppColors.error;
                  backgroundColor = AppColors.error.withOpacity(0.1);
                  textColor = AppColors.error;
                } else if (isSelected) {
                  borderColor = AppColors.primary;
                  backgroundColor = AppColors.primary.withOpacity(0.1);
                  textColor = AppColors.primary;
                }

                return InkWell(
                  onTap: _isAlreadySubmitted
                      ? null
                      : () {
                          setState(() {
                            // Clear previous selection for this question and add new
                            _selectedOptions[question.id] = [option.id];
                          });
                        },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: (showCorrect || showWrong || isSelected) ? 2 : 1,
                      ),
                      color: backgroundColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: showCorrect
                                ? AppColors.success
                                : showWrong
                                    ? AppColors.error
                                    : isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.content,
                              style: GoogleFonts.inter(
                                color: textColor,
                                fontWeight:
                                    (showCorrect || showWrong || isSelected)
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),

            // Model Answer (Correct Answer)
            // Show if Teacher OR (Student is reviewing AND exam is graded)
            // Check for either text answer or image answer
            if (((question.correctAnswer != null &&
                        question.correctAnswer!.isNotEmpty &&
                        question.correctAnswer != '0') ||
                    (question.correctAnswerImageUrl != null &&
                        question.correctAnswerImageUrl!.isNotEmpty)) &&
                (widget.isTeacher ||
                    (_isReviewing && _isAlreadySubmitted && _isGraded)))
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الإجابة النموذجية',
                          style: GoogleFonts.outfit(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Show text answer if available
                    if (question.correctAnswer != null &&
                        question.correctAnswer!.isNotEmpty &&
                        question.correctAnswer != '0')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          question.correctAnswer!,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    // Show image answer if available
                    if (question.correctAnswerImageUrl != null &&
                        question.correctAnswerImageUrl!.isNotEmpty) ...[
                      if (question.correctAnswer != null &&
                          question.correctAnswer!.isNotEmpty &&
                          question.correctAnswer != '0')
                        const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
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
                                          question.correctAnswerImageUrl!,
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
                                        onPressed: () => Navigator.pop(context),
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                          child: Image.network(
                            question.correctAnswerImageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 100,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text('تعذر تحميل الصورة'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Teacher Grading Section
            if (widget.isTeacher &&
                _isReviewing &&
                widget.viewingStudentId != null)
              _buildTeacherGradingSection(question),
          ],
        ),
      ),
    );
  }

  Future<void> _editStudentAnswerImage(
    int questionId,
    int studentAnswerId,
  ) async {
    // Show options: Pick new image OR Draw on existing
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: AppColors.primary),
              title: const Text('اختيار صورة جديدة من المعرض'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primary),
              title: const Text('الرسم على الصورة الحالية'),
              onTap: () => Navigator.pop(context, 'draw'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;

    List<int>? newImageBytes;
    String fileName = 'edited_answer.png';

    if (action == 'gallery') {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      newImageBytes = await image.readAsBytes();
      fileName = image.name;
    } else if (action == 'draw') {
      // Get current image URL
      final currentUrl = _studentAnswerResults[questionId]?.imageAnswerUrl;
      if (currentUrl == null || currentUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد صورة حالية للتعديل عليها')),
        );
        return;
      }

      // Navigate to Image Editor
      final Uint8List? editedBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditorScreen(imageUrl: currentUrl),
        ),
      );

      if (editedBytes == null) return; // Cancelled
      newImageBytes = editedBytes.toList();
    }

    if (newImageBytes == null) return;

    setState(() {
      _isUploadingImage[questionId] = true;
    });

    final response = await _teacherService.updateStudentAnswerImage(
      studentAnswerId: studentAnswerId,
      imageBytes: newImageBytes,
      fileName: fileName,
    );

    if (mounted) {
      setState(() {
        _isUploadingImage[questionId] = false;
      });

      if (response.succeeded) {
        // Update the image URL in local state just in case (optional now)
        // But crucially, reload the exam data to ensure sync, while keeping scroll position.

        final double currentScrollOffset =
            _scrollController.hasClients ? _scrollController.offset : 0.0;

        await _fetchExam();

        // Restore scroll position
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(currentScrollOffset);
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الصورة بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
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

  Widget _buildImageAnswerInput(Question question) {
    if (_isAlreadySubmitted || _isReviewing) {
      // Show submitted answer (Network Image)
      String? url;
      // If locally just submitted, might be in _uploadedImageUrls
      // If reviewing from API, it's in _studentAnswerResults
      if (_isReviewing && _studentAnswerResults.containsKey(question.id)) {
        url = _studentAnswerResults[question.id]?.imageAnswerUrl;
      } else {
        url = _uploadedImageUrls[question.id];
      }

      if (url == null || url.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 8),
              Text(
                'لم يتم ارفاق صورة',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إجابتك:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              // Edit button for teacher
              if (widget.isTeacher &&
                  _isReviewing &&
                  _studentAnswerResults.containsKey(question.id) &&
                  _studentAnswerResults[question.id]?.studentAnswerId != null &&
                  _studentAnswerResults[question.id]?.studentAnswerId != 0)
                TextButton.icon(
                  onPressed: () => _editStudentAnswerImage(
                    question.id,
                    _studentAnswerResults[question.id]!.studentAnswerId,
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('تعديل الصورة'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
                            url!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
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
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
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
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: AppColors.surfaceLight,
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isUploadingImage[question.id] == true)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                if (_isUploadingImage[question.id] == true)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // Editable Mode
    final localPath = _localImagePaths[question.id];
    final isUploading = _isUploadingImage[question.id] ?? false;
    final isUploaded = _uploadedImageUrls.containsKey(question.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (localPath != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(
                        localPath,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(localPath),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              if (!isUploading && isUploaded)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: () {
                    // Remove image
                    setState(() {
                      _localImagePaths.remove(question.id);
                      _uploadedImageUrls.remove(question.id);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      _pickAndUploadImage(question.id, ImageSource.gallery),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_library_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'المعرض',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      _pickAndUploadImage(question.id, ImageSource.camera),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الكاميرا',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickAndUploadImage(
    int questionId, [
    ImageSource source = ImageSource.gallery,
  ]) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
    ); // Or show bottom sheet for Camera/Gallery

    if (image != null) {
      if (!mounted) return;
      setState(() {
        _localImagePaths[questionId] = image.path;
        _isUploadingImage[questionId] = true;
      });

      // Upload
      final studentId = await _tokenService.getUserId();
      if (studentId != null && _exam != null) {
        final response = await _courseService.uploadStudentImageAnswer(
          examId: _exam!.id,
          studentId: studentId,
          questionId: questionId,
          image: image,
          studentExamResultId: _studentExamResultId,
        );

        if (mounted) {
          if (response.succeeded && response.data != null) {
            setState(() {
              // Use the returned ID/URL. If it's just an ID "123", we might treat it as such.
              // The prompt implies we need a URL for submit.
              // If the response is simply a string ID, we store it.
              _uploadedImageUrls[questionId] = response.data!;
              _isUploadingImage[questionId] = false;
            });
          } else {
            setState(() => _isUploadingImage[questionId] = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل رفع الصورة: ${response.message}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else {
        if (mounted) setState(() => _isUploadingImage[questionId] = false);
      }
    }
  }

  Widget _buildTeacherGradingSection(Question question) {
    final result = _studentAnswerResults[question.id];
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(color: AppColors.glassBorder),
        ),
        Row(
          children: [
            Icon(Icons.grading_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text(
              'تصحيح المعلم:',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الدرجة المستحقة (من ${question.score}):',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _teacherPoints[question.id]?.toString() ?? '',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '0.0',
                      filled: true,
                      fillColor: AppColors.surfaceLight.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) {
                      final score = double.tryParse(val);
                      if (score != null) {
                        _teacherPoints[question.id] = score;
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملاحظات / تعليق:',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _teacherFeedback[question.id] ?? '',
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'أحسنت / حاول مرة أخرى...',
                      filled: true,
                      fillColor: AppColors.surfaceLight.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) {
                      _teacherFeedback[question.id] = val;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitGrading() async {
    if (_studentExamResultId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final gradedAnswers = <GradedAnswerRequest>[];

      for (var q in _exam!.questions) {
        final result = _studentAnswerResults[q.id];
        if (result == null) continue;

        // ── MCQ: auto-grade on backend by comparing answers ────────
        // Do NOT send MCQ to the manual grading API.
        // The backend's correctAllExams / auto-grade handles MCQ.
        // We only send truly manual (essay/image) questions.

        final bool isMCQ = q.answerType != 'TextAnswer' &&
            q.answerType != 'ImageAnswer' &&
            q.questionType != 'Image';

        if (isMCQ) {
          // Skip — MCQ is auto-graded server-side
          print('⏭ Skipping MCQ question ${q.id} (auto-graded by server)');
          continue;
        }

        // ── Essay / Image: manual grading ──────────────────────────
        final points = _teacherPoints[q.id] ?? result.pointsEarned ?? 0.0;
        final feedback = _teacherFeedback[q.id] ?? result.feedback ?? '';

        final idToSend =
            result.studentAnswerId != 0 ? result.studentAnswerId : q.id;

        print(
          '✏️ Grading Essay: ID=$idToSend, QuestionID=${q.id}, Points=$points',
        );
        gradedAnswers.add(
          GradedAnswerRequest(
            studentAnswerId: idToSend,
            pointsEarned: points,
            isCorrect: points >= (q.score / 2),
            feedback: feedback,
          ),
        );
      }

      if (gradedAnswers.isEmpty) {
        // No essay answers to grade
        if (_bonusPoints > 0) {
          // If there's a bonus but no essay questions, show a warning
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'لا توجد أسئلة مقالية لإضافة الدرجة الإضافية عليها',
                ),
                backgroundColor: AppColors.warning,
              ),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }
        // No essay answers and no bonus - just show success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ التصحيح بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          await _fetchExam();
        }
        return;
      }

      // Distribute bonus points on top of the first essay answer
      if (_bonusPoints > 0 && gradedAnswers.isNotEmpty) {
        final first = gradedAnswers.first;
        gradedAnswers[0] = GradedAnswerRequest(
          studentAnswerId: first.studentAnswerId,
          pointsEarned: first.pointsEarned + _bonusPoints,
          isCorrect: first.isCorrect,
          feedback: first.feedback,
        );
      }

      final request = GradeExamRequest(
        studentExamResultId: _studentExamResultId!,
        gradedAnswers: gradedAnswers,
      );

      // ══════════════════════════════════════════════════════
      print('');
      print('╔══════════════════════════════════════════════╗');
      print('║          📤 GRADE EXAM REQUEST BODY          ║');
      print('╠══════════════════════════════════════════════╣');
      print('║ studentExamResultId : $_studentExamResultId');
      print('║ bonusPoints applied : $_bonusPoints');
      print('║ total gradedAnswers : ${gradedAnswers.length}');
      print('╠══════════════════════════════════════════════╣');
      for (var i = 0; i < gradedAnswers.length; i++) {
        final a = gradedAnswers[i];
        print('║ Answer[$i]:');
        print('║   studentAnswerId : ${a.studentAnswerId}');
        print('║   pointsEarned    : ${a.pointsEarned}');
        print('║   isCorrect       : ${a.isCorrect}');
        print('║   feedback        : ${a.feedback ?? "—"}');
      }
      print('╠══════════════════════════════════════════════╣');
      print('║ Full JSON Body:');
      print('║   ${jsonEncode(request.toJson())}');
      print('╚══════════════════════════════════════════════╝');
      print('');
      // ══════════════════════════════════════════════════════

      final response = await _courseService.gradeExam(request);

      if (response.succeeded && response.data != null) {
        if (mounted) {
          // Immediately mark as graded
          setState(() {
            _isGraded = true;
          });
          await _showGradingResultDialog(response.data!);
        }
        // Refresh data to show new score and get gradedByName from server
        if (mounted) {
          await _fetchExam();
        }
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('خطأ في حفظ التصحيح: ${_getErrorMessage(e.toString())}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showGradingResultDialog(GradeExamResponse data) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 12),
            Text(
              'تم التصحيح بنجاح',
              style: GoogleFonts.outfit(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.message,
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _buildResultRow(
              'الدرجة السابقة',
              data.previousTotalScore.toStringAsFixed(1),
            ),
            const SizedBox(height: 12),
            _buildResultRow(
              'النقاط المضافة',
              '+${data.pointsFromManualGrading.toStringAsFixed(1)}',
              color: AppColors.success,
            ),
            Divider(color: AppColors.glassBorder, height: 24),
            _buildResultRow(
              'الدرجة الجديدة',
              data.newTotalScore.toStringAsFixed(1),
              isBold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'حسناً',
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color ?? AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 20 : 16,
          ),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }

  Widget _buildTeacherGradingFooter() {
    final pending = _getPendingCount();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show graded status
            if (_isGraded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تم التصحيح',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        if (_gradedByName != null && _gradedByName!.isNotEmpty)
                          Text(
                            'بواسطة: $_gradedByName',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.success.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Still allow re-grading
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _submitGrading,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'إعادة التصحيح',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
            ] else ...[
              if (pending > 0 && !_isSubmitting)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'يوجد $pending أسئلة بانتظار تصحيحك',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

              // ── Submit Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitGrading,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'حفظ التصحيح النهائي',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
