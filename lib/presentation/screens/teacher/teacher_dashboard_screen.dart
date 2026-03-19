import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import '../auth/login_screen.dart';
import 'package:edu_platform_app/data/models/course_models.dart';
import 'package:edu_platform_app/data/services/teacher_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:edu_platform_app/data/services/subject_service.dart';
import '../shared/course_details/course_details_screen.dart';
import 'package:edu_platform_app/data/services/auth_service.dart';
import 'package:edu_platform_app/data/services/assistant_service.dart';
import 'edit_teacher_profile_screen.dart'; // Added import
import 'package:edu_platform_app/presentation/widgets/dialogs/add_student_to_course_dialog.dart';
import 'teacher_subscriptions_screen.dart';
import 'manage_assistants_screen.dart';
import 'teacher_revenue_screen.dart';
import 'course_students_scores_screen.dart';
import '../auth/change_password_screen.dart';
import 'package:edu_platform_app/data/services/settings_service.dart';
import 'package:edu_platform_app/core/constants/app_constants.dart';
import 'package:edu_platform_app/data/services/theme_service.dart';
import 'package:edu_platform_app/data/services/notification_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final int? teacherId; // Optional teacher ID for admin view
  final String? teacherUserId; // Teacher's userId (GUID) for admin view
  final bool isAdminView; // Flag to indicate if admin is viewing

  const TeacherDashboardScreen({
    super.key,
    this.teacherId,
    this.teacherUserId,
    this.isAdminView = false,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _currentIndex = 0;
  final _tokenService = TokenService();

  @override
  void initState() {
    super.initState();
    // Process any pending notification that launched the app from terminated state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.processPendingNotification();
    });
  }

  Future<void> _performLogout() async {
    // Get userId before clearing tokens
    final userId = await _tokenService.getUserGuid();

    // Call logout API to end session on server
    if (userId != null && userId.isNotEmpty) {
      final authService = AuthService();
      final response = await authService.logoutAllDevices(userId);
      print('--- Logout API Response ---');
      print('Succeeded: ${response.succeeded}');
      print('Message: ${response.message}');
      print('---------------------------');
    }

    // Clear local tokens
    await _tokenService.clearTokens();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'حذف الحساب',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد حذف الحساب؟',
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.inter(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'حذف الحساب',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الحساب', textAlign: TextAlign.center),
            backgroundColor: AppColors.error,
          ),
        );
      }
      await _performLogout();
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد أنك تريد تسجيل الخروج؟',
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.inter(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'تسجيل الخروج',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _TeacherCoursesPage(teacherId: widget.teacherId),
          const _TeacherProfilePage(),
          _TeacherSettingsPage(
            onLogout: _handleLogout,
            teacherId: widget.teacherId,
            teacherUserId: widget.teacherUserId, // forward GUID for admin view
            onDeleteAccount: _handleDeleteAccount,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : AppColors.primary;

    final items = <Map<String, dynamic>>[
      {'icon': Icons.play_lesson_rounded, 'label': 'دوراتي'},
      {'icon': Icons.person_rounded, 'label': 'الملف'},
      {'icon': Icons.settings_rounded, 'label': 'الإعدادات'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final isSelected = _currentIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 12 : 8,
                  vertical: isSelected ? 8 : 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? AppColors.primary.withOpacity(0.2)
                          : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[index]['icon'] as IconData,
                      size: 22,
                      color: isSelected
                          ? (isDark ? AppColors.primary : AppColors.primary)
                          : (isDark
                              ? Colors.white.withOpacity(0.4)
                              : Colors.white.withOpacity(0.6)),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          items[index]['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? AppColors.primary : AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TEACHER COURSES PAGE
// ═══════════════════════════════════════════════════════════════════════

class _TeacherCoursesPage extends StatefulWidget {
  final int? teacherId; // Optional teacher ID for admin view

  const _TeacherCoursesPage({this.teacherId});

  @override
  State<_TeacherCoursesPage> createState() => _TeacherCoursesPageState();
}

class _TeacherCoursesPageState extends State<_TeacherCoursesPage> {
  final _tokenService = TokenService();
  final _teacherService = TeacherService();
  final _subjectService = SubjectService();
  final _assistantService = AssistantService();
  bool _isLoading = false;
  List<Course> _courses = [];
  List<Map<String, dynamic>> _educationStages = [];
  bool _isAssistant = false; // Track if user is assistant
  String? _teacherName; // Store teacher name for dashboard

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _fetchEducationStages();
    _updateConfig();
    // _fetchCourses() removed from here, called in _checkUserRole
  }

  Future<void> _updateConfig() async {
    try {
      final settingsService = SettingsService();
      final response = await settingsService.getIconPricerEnabled();
      if (mounted && response.succeeded) {
        setState(() {
          AppConstants.data = response.data ?? false;
        });
      }
    } catch (e) {
      print('Error updating config: $e');
    }
  }

  // Helper method to convert Arabic numerals to English
  String _convertArabicToEnglishNumbers(String input) {
    const arabicNumerals = '٠١٢٣٤٥٦٧٨٩';
    const englishNumerals = '0123456789';

    String result = input;
    for (int i = 0; i < arabicNumerals.length; i++) {
      result = result.replaceAll(arabicNumerals[i], englishNumerals[i]);
    }
    return result;
  }

  Future<void> _checkUserRole() async {
    final role = await _tokenService.getRole();
    if (mounted) {
      setState(() {
        _isAssistant = role == 'Assistant';
      });
      _fetchCourses(); // Call here after role is determined
    }
  }

  Future<void> _fetchEducationStages() async {
    final response = await _subjectService.getEducationStages();
    if (mounted && response.succeeded && response.data != null) {
      setState(() {
        _educationStages = response.data!;
      });
    }
  }

  Future<void> _fetchCourses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    int? targetTeacherId;

    // If teacherId is provided (admin view), use it directly
    if (widget.teacherId != null) {
      targetTeacherId = widget.teacherId!;
    } else {
      // Get saved teacher ID
      targetTeacherId = await _tokenService.getTeacherId();

      // If saved ID is invalid, try to resolve it
      if (targetTeacherId == null || targetTeacherId == 0) {
        final userGuid = await _tokenService.getUserGuid();

        if (_isAssistant) {
          if (userGuid != null) {
            final assistantResponse =
                await _assistantService.getAssistantByUserId(userGuid);

            if (assistantResponse.succeeded && assistantResponse.data != null) {
              targetTeacherId = assistantResponse.data!.teacherId;
              await _tokenService.saveTeacherId(targetTeacherId);
            }
          }
        } else {
          // Teacher Role
          if (userGuid != null) {
            final profileResponse = await _teacherService.getProfileByGuid(
              userGuid,
            );
            if (profileResponse.succeeded && profileResponse.data != null) {
              targetTeacherId = profileResponse.data!['teacherId'];
              if (mounted) {
                setState(() {
                  _teacherName = profileResponse.data!['fullName'];
                });
              }
              if (targetTeacherId != null) {
                await _tokenService.saveTeacherId(targetTeacherId!);
              }
            }
          }
        }
      }

      // Fallback to generic userId if still not found
      if (targetTeacherId == null || targetTeacherId == 0) {
        final userId = await _tokenService.getUserId();
        if (userId != null) {
          targetTeacherId = userId;
        }
      }
    }

    if (targetTeacherId == null || targetTeacherId == 0) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Could show an error or empty state here, but for now just stop loading
        print('Could not resolve Teacher ID');
      }
      return;
    }

    final response = await _teacherService.getTeacherCourses(targetTeacherId!);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.succeeded && response.data != null) {
          _courses = response.data!;
          _courses.sort((a, b) => a.index.compareTo(b.index));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      });
    }
  }

  Future<void> _showAddCourseDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final gradeYearController = TextEditingController();
    final priceController = TextEditingController();
    final discountedPriceController = TextEditingController();

    int? selectedStageId;
    String? selectedImagePath;
    final picker = ImagePicker();

    Future<void> pickImage(StateSetter setState) async {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => selectedImagePath = image.path);
      }
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sbContext, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'إضافة دورة جديدة',
              style: GoogleFonts.outfit(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'عنوان الدورة',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    maxLines: 3,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Picker
                  GestureDetector(
                    onTap: () => pickImage(setState),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        image: selectedImagePath != null
                            ? DecorationImage(
                                image: FileImage(File(selectedImagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: selectedImagePath == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                  size: 40,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'تحميل صورة الدورة',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedStageId,
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: InputDecoration(
                      labelText: 'المرحلة الدراسية',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    style: GoogleFonts.inter(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    items: _educationStages.map((stage) {
                      return DropdownMenuItem<int>(
                        value: stage['id'],
                        child: Text(
                          stage['name'] ?? '',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedStageId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: gradeYearController,
                    decoration: InputDecoration(
                      labelText: 'السنة الدراسية',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (AppConstants.data) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'السعر',
                        labelStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: discountedPriceController,
                      decoration: InputDecoration(
                        labelText: 'السعر المخفض',
                        labelStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
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
                  if (titleController.text.isNotEmpty &&
                      gradeYearController.text.isNotEmpty &&
                      selectedStageId != null) {
                    Navigator.pop(dialogContext);

                    // Use widget.teacherId if available (admin view), otherwise use effective teacher ID
                    int? teacherId = widget.teacherId;

                    if (teacherId == null) {
                      teacherId = await _tokenService.getTeacherId();

                      // If still null or 0, try to recover it
                      if (teacherId == null || teacherId == 0) {
                        final userGuid = await _tokenService.getUserGuid();
                        if (userGuid != null) {
                          final profileResponse =
                              await _teacherService.getProfileByGuid(userGuid);
                          if (profileResponse.succeeded &&
                              profileResponse.data != null) {
                            teacherId = profileResponse.data!['teacherId'];
                            if (teacherId != null) {
                              await _tokenService.saveTeacherId(teacherId);
                            }
                          }
                        }
                      }
                    }

                    final request = CourseRequest(
                      title: titleController.text,
                      description: descriptionController.text.isNotEmpty
                          ? descriptionController.text
                          : null,
                      gradeYear: int.parse(
                        _convertArabicToEnglishNumbers(
                          gradeYearController.text,
                        ),
                      ),
                      teacherId: teacherId ?? 0,
                      educationStageId: selectedStageId!,
                      price: double.parse(
                        _convertArabicToEnglishNumbers(priceController.text),
                      ),
                      discountedPrice: double.parse(
                        _convertArabicToEnglishNumbers(
                          discountedPriceController.text,
                        ),
                      ),
                      imagePath: selectedImagePath,
                    );

                    final response = await _teacherService.createCourse(
                      request,
                    );
                    if (!mounted) return;

                    if (mounted && context.mounted) {
                      if (response.succeeded) {
                        // Ensure backend has processed the addition before fetching
                        await Future.delayed(const Duration(milliseconds: 300));
                        await _fetchCourses();

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إضافة الدورة بنجاح'),
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _selectedStage;

  List<String> _getUniqueStages() {
    // Build a map: stageName -> min educationStageId (gradeYear) for proper ordering
    final stageOrderMap = <String, int>{};
    for (final c in _courses) {
      final name = c.educationStageName?.isNotEmpty == true
          ? c.educationStageName!
          : 'أخرى';
      final stageId = c.gradeYear; // gradeYear holds educationStageId from API
      if (!stageOrderMap.containsKey(name) || stageId < stageOrderMap[name]!) {
        stageOrderMap[name] = stageId;
      }
    }
    final stages = stageOrderMap.keys.toList();
    // Sort by educationStageId (ascending) so الأول < الثاني < الثالث
    stages.sort(
        (a, b) => (stageOrderMap[a] ?? 0).compareTo(stageOrderMap[b] ?? 0));
    return ['الكل', ...stages];
  }

  @override
  Widget build(BuildContext context) {
    // ── Ramadan detection (Egypt = UTC+2, no DST) ────────────────────────
    final egyptNow = DateTime.now().toUtc().add(const Duration(hours: 2));
    final isRamadan = _checkRamadan(egyptNow);

    // ── Theme tokens ─────────────────────────────────────────────────────
    final appBarGradient = isRamadan
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B0000),
              Color(0xFF7B0000),
              Color(0xFFB71C1C),
              Color(0xFF5A0A0A),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB71C1C),
              Color(0xFFE53935),
              Color(0xFFEF5350),
              Color(0xFFD32F2F),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          );

    final shadowColor = isRamadan
        ? const Color.fromARGB(255, 94, 27, 27).withOpacity(0.55)
        : const Color(0xFFE53935).withOpacity(0.45);

    final collapsedBg =
        isRamadan ? const Color(0xFF3B0000) : const Color(0xFFB71C1C);

    // Pre-compute filtered list
    final filteredCourses = _courses.where((c) {
      if (_selectedStage == null) return true;
      final stageName = c.educationStageName?.isNotEmpty == true
          ? c.educationStageName!
          : 'أخرى';
      return stageName == _selectedStage;
    }).toList();

    // Course count for subtitle
    final courseCount = _courses.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _isAssistant
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddCourseDialog,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: Text('إضافة دورة',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
      body: RefreshIndicator(
        onRefresh: _fetchCourses,
        color: AppColors.primary,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // ── Collapsible SliverAppBar ─────────────────────────────
            SliverAppBar(
              expandedHeight: 190,
              collapsedHeight: 65,
              toolbarHeight: 65,
              pinned: true,
              floating: false,
              snap: false,
              elevation: 10,
              forceElevated: true,
              scrolledUnderElevation: 10,
              surfaceTintColor: Colors.transparent,
              shadowColor: shadowColor,
              backgroundColor: collapsedBg,
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),

              // ── Collapsed bar ────────────────────────────────────
              title: Row(
                children: [
                  if (widget.teacherId != null) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Logo
                  Container(
                    height: 32,
                    width: 32,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/images/logo_icon.png',
                        fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _teacherName != null
                              ? 'أهلاً، $_teacherName'
                              : 'لوحة تحكم المعلم',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (courseCount > 0)
                          Text(
                            '$courseCount دورات',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isRamadan)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.nightlight_round,
                              color: Color(0xFFFFD54F), size: 12),
                          const SizedBox(width: 3),
                          Text(
                            'رمضان',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFFD54F),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: _fetchCourses,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // ── Expanded FlexibleSpaceBar ────────────────────────
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: appBarGradient,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(32)),
                  ),
                  child: Stack(
                    children: [
                      // ── Decorative mesh orbs ──────────────────────
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.12),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 60,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 30,
                        left: -40,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.08),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 60,
                        right: 30,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                        ),
                      ),

                      // ── Ramadan decorations ───────────────────────
                      if (isRamadan) ...[
                        // Main crescent
                        Positioned(
                          top: 24,
                          right: 16,
                          child: Icon(Icons.nightlight_round,
                              color: const Color(0xFFFFD54F).withOpacity(0.50),
                              size: 32),
                        ),
                        // Stars constellation
                        Positioned(
                          top: 18,
                          right: 50,
                          child: Icon(Icons.star_rounded,
                              color: const Color(0xFFFFD54F).withOpacity(0.35),
                              size: 12),
                        ),
                        Positioned(
                          top: 36,
                          right: 52,
                          child: Icon(Icons.star_rounded,
                              color: const Color(0xFFFFD54F).withOpacity(0.20),
                              size: 8),
                        ),
                        Positioned(
                          top: 14,
                          right: 70,
                          child: Icon(Icons.star_rounded,
                              color: const Color(0xFFFFD54F).withOpacity(0.15),
                              size: 6),
                        ),
                        Positioned(
                          top: 42,
                          right: 70,
                          child: Icon(Icons.auto_awesome,
                              color: const Color(0xFFFFD54F).withOpacity(0.12),
                              size: 14),
                        ),
                        // Subtle lantern glow bottom-left
                        Positioned(
                          bottom: 50,
                          left: 18,
                          child: Icon(Icons.auto_awesome,
                              color: const Color(0xFFFFD54F).withOpacity(0.08),
                              size: 20),
                        ),
                      ],

                      // ── Main content ──────────────────────────────
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 70),

                              // ── Shimmer divider ─────────
                              Container(
                                height: 1.2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(1),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.35),
                                      Colors.white.withOpacity(0.15),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // ── Quick Actions (glassmorphic) ──
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildQuickAction(
                                      icon: Icons.person_add_rounded,
                                      label: 'طالب',
                                      color: isRamadan
                                          ? const Color(0xFFFFD54F)
                                          : const Color(0xFFFFB300),
                                      onTap: () async {
                                        int? teacherId = widget.teacherId;
                                        if (teacherId == null) {
                                          teacherId = await _tokenService
                                              .getTeacherId();
                                        }
                                        if (teacherId != null && mounted) {
                                          AddStudentToCourseDialog.show(
                                            context,
                                            teacherId: teacherId!,
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildQuickAction(
                                      icon: Icons.notifications_active_rounded,
                                      label: 'اشتراكات',
                                      color: Colors.white,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TeacherSubscriptionsScreen(
                                              teacherId: widget.teacherId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (AppConstants.data && !_isAssistant) ...[
                                      const SizedBox(width: 8),
                                      _buildQuickAction(
                                        icon: Icons.analytics_rounded,
                                        label: 'أرباح',
                                        color: const Color(0xFF69F0AE),
                                        onTap: () async {
                                          int? teacherId = widget.teacherId;
                                          if (teacherId == null) {
                                            teacherId = await _tokenService
                                                .getTeacherId();
                                          }
                                          if (teacherId != null && mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TeacherRevenueScreen(
                                                  teacherId: teacherId!,
                                                  teacherName:
                                                      _teacherName ?? 'المعلم',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                    if (_courses.length > 1 &&
                                        !_isAssistant) ...[
                                      const SizedBox(width: 8),
                                      _buildQuickAction(
                                        icon: Icons.swap_vert_rounded,
                                        label: 'ترتيب',
                                        color: Colors.white,
                                        onTap: _showReorderCoursesSheet,
                                      ),
                                    ],
                                  ],
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

              // ── Filter chips ─────────────────────────────────────
              bottom: _courses.isEmpty
                  ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(56),
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.only(bottom: 8),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 0.5,
                              child: Container(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                children: _getUniqueStages().map((stage) {
                                  final isDark = Theme.of(context).brightness ==
                                      Brightness.dark;
                                  final isSelected = (_selectedStage == null &&
                                          stage == 'الكل') ||
                                      _selectedStage == stage;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        stage,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.white
                                              : Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedStage =
                                              stage == 'الكل' ? null : stage;
                                        });
                                      },
                                      selectedColor: AppColors.primary,
                                      backgroundColor: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.black.withOpacity(0.05),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark
                                                ? Colors.white.withOpacity(0.12)
                                                : Colors.black
                                                    .withOpacity(0.1)),
                                        width: isSelected ? 1.5 : 0.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 0),
                                      showCheckmark: false,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // ── Body ─────────────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (filteredCourses.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.primaryGradient.createShader(bounds),
                          child: const Icon(
                            Icons.class_outlined,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'لا توجد دورات',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على الزر أدناه لإضافة دورة',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildCourseCard(filteredCourses[index]),
                    childCount: filteredCourses.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Returns true if [now] (Egypt time, UTC+2) falls within a known Ramadan.
  bool _checkRamadan(DateTime now) {
    const periods = [
      (begin: (y: 2026, m: 2, d: 18), end: (y: 2026, m: 3, d: 19)),
      (begin: (y: 2027, m: 2, d: 8), end: (y: 2027, m: 3, d: 9)),
      (begin: (y: 2028, m: 1, d: 28), end: (y: 2028, m: 2, d: 26)),
    ];
    for (final p in periods) {
      final start = DateTime(p.begin.y, p.begin.m, p.begin.d);
      final finish = DateTime(p.end.y, p.end.m, p.end.d, 23, 59, 59);
      if (!now.isBefore(start) && !now.isAfter(finish)) return true;
    }
    return false;
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
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

  Future<void> _showEditCourseDialog(Course course) async {
    final titleController = TextEditingController(text: course.title);
    final descriptionController =
        TextEditingController(text: course.description ?? '');
    final gradeYearController = TextEditingController(
      text: course.gradeYear.toString(),
    );
    final priceController = TextEditingController(
      text: course.price.toStringAsFixed(0),
    );
    final discountedPriceController = TextEditingController(
      text: course.discountedPrice.toStringAsFixed(0),
    );

    // Try to find matching stage by name if ID isn't available, or rely on gradeYear if it matches ID
    // Since Course model merges them, let's try to assume gradeYear might be it, or default to null
    int? selectedStageId;
    String? selectedImagePath;
    final picker = ImagePicker();

    Future<void> pickImage(StateSetter setState) async {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => selectedImagePath = image.path);
      }
    }

    // Attempt to pre-select based on response data matching
    if (course.educationStageName != null) {
      final matchingStage = _educationStages.firstWhere(
        (s) => s['name'] == course.educationStageName,
        orElse: () => {},
      );
      if (matchingStage.isNotEmpty) {
        selectedStageId = matchingStage['id'];
      }
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sbContext, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'تعديل الدورة',
              style: GoogleFonts.outfit(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'عنوان الدورة',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    maxLines: 3,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Picker
                  GestureDetector(
                    onTap: () => pickImage(setState),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                        image: selectedImagePath != null
                            ? DecorationImage(
                                image: FileImage(File(selectedImagePath!)),
                                fit: BoxFit.cover,
                              )
                            : (course.courseImageUrl != null &&
                                    course.courseImageUrl!.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(course.courseImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                      ),
                      child: (selectedImagePath == null &&
                              (course.courseImageUrl == null ||
                                  course.courseImageUrl!.isEmpty))
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                  size: 40,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'تغيير صورة الدورة',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    value: selectedStageId,
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: InputDecoration(
                      labelText: 'المرحلة الدراسية',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    style: GoogleFonts.inter(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    items: _educationStages.map((stage) {
                      return DropdownMenuItem<int>(
                        value: stage['id'],
                        child: Text(
                          stage['name'] ?? '',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedStageId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: gradeYearController,
                    decoration: InputDecoration(
                      labelText: 'السنة الدراسية',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (AppConstants.data) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'السعر',
                        labelStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: discountedPriceController,
                      decoration: InputDecoration(
                        labelText: 'السعر المخفض',
                        labelStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
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
                  if (titleController.text.isNotEmpty &&
                      gradeYearController.text.isNotEmpty &&
                      selectedStageId != null) {
                    Navigator.pop(dialogContext);

                    // Use widget.teacherId if available (admin view), otherwise use current user's ID
                    final teacherId =
                        widget.teacherId ?? await _tokenService.getTeacherId();

                    final request = CourseRequest(
                      title: titleController.text,
                      description: descriptionController.text.isNotEmpty
                          ? descriptionController.text
                          : null,
                      gradeYear: int.parse(
                        _convertArabicToEnglishNumbers(
                          gradeYearController.text,
                        ),
                      ),
                      teacherId: teacherId ?? 0,
                      educationStageId: selectedStageId!,
                      price: double.parse(
                        _convertArabicToEnglishNumbers(priceController.text),
                      ),
                      discountedPrice: double.parse(
                        _convertArabicToEnglishNumbers(
                          discountedPriceController.text,
                        ),
                      ),
                      imagePath: selectedImagePath,
                    );

                    final response = await _teacherService.updateCourse(
                      request,
                      course.id,
                    );
                    if (!mounted) return;

                    if (mounted && context.mounted) {
                      if (response.succeeded) {
                        _fetchCourses();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تحديث الدورة بنجاح'),
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteCourse(int courseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('حذف الدورة'),
        content: const Text(
          'هل أنت متأكد أنك تريد حذف هذه الدورة؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _teacherService.deleteCourse(courseId);
      if (!mounted) return;

      if (mounted && context.mounted) {
        if (response.succeeded) {
          _fetchCourses();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حذف الدورة')));
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
  }

  Widget _buildCourseCard(Course course) {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CourseDetailsScreen(course: course, isTeacher: true),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Image Section
                Stack(
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        color: AppColors.surface,
                        image: course.courseImageUrl != null &&
                                course.courseImageUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(course.courseImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: (course.courseImageUrl == null ||
                              course.courseImageUrl!.isEmpty)
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.8),
                                    AppColors.primary.withOpacity(0.4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.play_lesson_rounded,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            )
                          : null,
                    ),
                    // Gradient Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Menu Button
                    Positioned(
                      top: 8,
                      left: 8,
                      child: PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditCourseDialog(course);
                          } else if (value == 'delete') {
                            _deleteCourse(course.id);
                          } else if (value == 'scores') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CourseStudentsScoresScreen(
                                  courseId: course.id,
                                  courseTitle: course.title,
                                ),
                              ),
                            );
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem(
                            value: 'scores',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.leaderboard_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'عرض الدرجات',
                                  style: GoogleFonts.inter(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isAssistant) ...[
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'تعديل',
                                    style: GoogleFonts.inter(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete_rounded,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'حذف',
                                    style: GoogleFonts.inter(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Stage Badge
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          course.educationStageName ?? '${course.gradeYear}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Content Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (course.description != null &&
                          course.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          course.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (AppConstants.data) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (course.discountedPrice > 0 &&
                                course.discountedPrice < course.price) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${course.discountedPrice.toStringAsFixed(0)} ج.م',
                                  style: GoogleFonts.inter(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${course.price.toStringAsFixed(0)} ج.م',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 12,
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${course.price.toStringAsFixed(0)} ج.م',
                                  style: GoogleFonts.inter(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.play_lesson_outlined,
                            size: 16,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${course.lectures.length} محاضرات',
                            style: GoogleFonts.inter(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReorderCoursesSheet() {
    // Filter courses by selected stage (same logic as build method)
    final coursesToReorder = _courses.where((c) {
      if (_selectedStage == null) return true;
      final stageName = c.educationStageName?.isNotEmpty == true
          ? c.educationStageName!
          : 'أخرى';
      return stageName == _selectedStage;
    }).toList();

    if (coursesToReorder.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد دورات كافية للترتيب في هذه المرحلة'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReorderCoursesSheet(
        courses: coursesToReorder,
        teacherService: _teacherService,
        onReordered: _fetchCourses,
      ),
    );
  }
}

class _ReorderCoursesSheet extends StatefulWidget {
  final List<Course> courses;
  final TeacherService teacherService;
  final VoidCallback onReordered;

  const _ReorderCoursesSheet({
    required this.courses,
    required this.teacherService,
    required this.onReordered,
  });

  @override
  State<_ReorderCoursesSheet> createState() => _ReorderCoursesSheetState();
}

class _ReorderCoursesSheetState extends State<_ReorderCoursesSheet> {
  late List<Course> _localCourses;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _localCourses = List.from(widget.courses);
  }

  Future<void> _saveOrder() async {
    setState(() => _isSaving = true);

    int teacherId = 0;
    if (_localCourses.isNotEmpty) {
      teacherId = _localCourses.first.teacherId;
    }

    if (teacherId == 0) {
      final tokenService = TokenService();
      teacherId = await tokenService.getTeacherId() ?? 0;
    }

    final newOrderIds = _localCourses.map((c) => c.id).toList();

    final response = await widget.teacherService.reorderCourses(
      teacherId,
      newOrderIds,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (response.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم ترتيب الدورات بنجاح')),
        );
        widget.onReordered();
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ترتيب الدورات',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _saveOrder,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('حفظ'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    disabledForegroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
              ),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _localCourses.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _localCourses.removeAt(oldIndex);
                    _localCourses.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final course = _localCourses[index];
                  return Container(
                    key: ValueKey(course.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.outfit(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        course.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.drag_handle_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TEACHER PROFILE PAGE
// ═══════════════════════════════════════════════════════════════════════

class _TeacherProfilePage extends StatefulWidget {
  const _TeacherProfilePage();

  @override
  State<_TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<_TeacherProfilePage> {
  final _tokenService = TokenService();
  final _teacherService = TeacherService();
  String? _userName;
  String? _userRole;
  String? _userEmail;
  int? _userId;
  String? _photoUrl;
  String? _phoneNumber;
  String? _facebookUrl;
  String? _telegramUrl;
  String? _whatsAppNumber;
  String? _city;
  String? _governorate;
  String? _subjectName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final name = await _tokenService.getUserName();
    final role = await _tokenService.getRole();
    final email = await _tokenService.getUserEmail();
    final userId = await _tokenService.getUserId();
    final photo = await _tokenService.getPhotoUrl();
    final phone = await _tokenService.getPhoneNumber();
    final facebook = await _tokenService.getFacebookUrl();
    final telegram = await _tokenService.getTelegramUrl();
    final whatsapp = await _tokenService.getWhatsAppNumber();

    // Initial load from local tokens
    if (mounted) {
      setState(() {
        _userName = name;
        _userRole = role;
        _userEmail = email;
        _userId = userId;
        _photoUrl = photo;
        _phoneNumber = phone;
        _facebookUrl = facebook;
        _telegramUrl = telegram;
        _whatsAppNumber = whatsapp;
      });
    }

    // Fetch fresh data from API
    final userGuid = await _tokenService.getUserGuid();
    if (userGuid != null) {
      final response = await _teacherService.getProfileByGuid(userGuid);
      if (mounted && response.succeeded && response.data != null) {
        final data = response.data!;
        setState(() {
          _city = data['city'];
          _governorate = data['governorate'];
          _subjectName = data['subjectName'];
          // Update other fields if available in detail
          if (data['phoneNumber'] != null) _phoneNumber = data['phoneNumber'];
          if (data['facebookUrl'] != null) _facebookUrl = data['facebookUrl'];
          if (data['telegramUrl'] != null) _telegramUrl = data['telegramUrl'];
          if (data['whatsAppNumber'] != null)
            _whatsAppNumber = data['whatsAppNumber'];
          // Note: Photo URL might need detailed handling if it's a full path or relative
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الملف الشخصي',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'معلوماتك الشخصية',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: _photoUrl != null
                              ? Image.network(
                                  _photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 50,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Theme.of(context).colorScheme.surface,
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 50,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _userName ?? 'اسم المستخدم',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _userRole == 'Teacher' ? 'معلم' : (_userRole ?? 'معلم'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildInfoTile(
                    'البريد الإلكتروني',
                    _userEmail ?? 'غير متوفر',
                  ),
                  const SizedBox(height: 16),
                  if (_phoneNumber != null) ...[
                    _buildInfoTile('رقم الهاتف', _phoneNumber!),
                    const SizedBox(height: 16),
                  ],
                  if (_whatsAppNumber != null) ...[
                    _buildInfoTile('واتساب', _whatsAppNumber!),
                    const SizedBox(height: 16),
                  ],
                  if (_governorate != null) ...[
                    _buildInfoTile('المحافظة', _governorate!),
                    const SizedBox(height: 16),
                  ],
                  if (_city != null) ...[
                    _buildInfoTile('المدينة', _city!),
                    const SizedBox(height: 16),
                  ],
                  if (_subjectName != null) ...[
                    _buildInfoTile('المادة', _subjectName!),
                    const SizedBox(height: 16),
                  ],
                  if (_facebookUrl != null || _telegramUrl != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_facebookUrl != null)
                          _buildSocialIcon(Icons.facebook, _facebookUrl!),
                        if (_facebookUrl != null && _telegramUrl != null)
                          const SizedBox(width: 16),
                        if (_telegramUrl != null)
                          _buildSocialIcon(Icons.send_rounded, _telegramUrl!),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildInfoTile(
                    'نوع الحساب',
                    _userRole == 'Teacher' ? 'معلم' : (_userRole ?? 'معلم'),
                  ),
                  if (_userId != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoTile('رقم المعرف', _userId.toString()),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String url) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.primary, size: 24),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TEACHER SETTINGS PAGE
// ═══════════════════════════════════════════════════════════════════════

class _TeacherSettingsPage extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback? onDeleteAccount;
  final int? teacherId; // Optional teacherId for admin view
  final String? teacherUserId; // Teacher's GUID for admin view (edit profile)

  const _TeacherSettingsPage({
    required this.onLogout,
    this.teacherId,
    this.teacherUserId,
    this.onDeleteAccount,
  });

  @override
  State<_TeacherSettingsPage> createState() => _TeacherSettingsPageState();
}

class _TeacherSettingsPageState extends State<_TeacherSettingsPage> {
  final _tokenService = TokenService();
  bool _deleteAccountEnabled = false;
  bool _isAssistant = false;

  @override
  void initState() {
    super.initState();
    _checkDeleteAccountEnabled();
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

  Future<void> _checkDeleteAccountEnabled() async {
    final settingsService = SettingsService();
    final response = await settingsService.getDeleteAccountEnabled();
    if (mounted && response.succeeded) {
      setState(() {
        _deleteAccountEnabled = response.data ?? false;
      });
    }
  }

  Future<void> _showEditProfileDialog() async {
    // Fetch current data
    final userId = await _tokenService.getUserGuid();

    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'خطأ: لم يتم العثور على معرف المستخدم. يرجى تسجيل الخروج وإعادة الدخول.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // For teachers, we navigate to the edit profile screen which handles fetching data
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditTeacherProfileScreen(
            // Prefer the teacher's GUID passed from admin view;
            // fall back to the logged-in user's own GUID for self-edit.
            targetUserGuid: widget.teacherUserId ?? userId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'الإعدادات',
              style: GoogleFonts.outfit(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Account Section
            _buildSection(
              title: 'الحساب',
              children: [
                _buildSettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'تعديل الملف الشخصي',
                  subtitle: 'تحديث معلوماتك الشخصية',
                  onTap: _showEditProfileDialog,
                ),
                _buildSettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'تغيير كلمة المرور',
                  subtitle: 'تحديث بيانات الأمان',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                if (!_isAssistant)
                  _buildSettingsTile(
                    icon: Icons.people_outline_rounded,
                    title: 'إدارة المساعدين',
                    subtitle: 'إضافة وإدارة المساعدين',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManageAssistantsScreen(
                              teacherId: widget.teacherId),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Preferences
            _buildSection(
              title: 'التفضيلات',
              children: [
                _buildSettingsTile(
                  icon: Icons.language_rounded,
                  title: 'اللغة',
                  subtitle: 'العربية',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اختيار اللغة قريباً!')),
                    );
                  },
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeService.themeModeNotifier,
                  builder: (context, mode, child) {
                    return _buildSettingsTile(
                      icon: mode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      title: 'المظهر',
                      subtitle: mode == ThemeMode.dark
                          ? 'الوضع الليلي'
                          : 'الوضع النهاري',
                      onTap: () async {
                        await ThemeService.toggleTheme();
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Logout Button
            // Logout Button
            Column(
              children: [
                _buildLogoutButton(),
                if (_deleteAccountEnabled &&
                    widget.onDeleteAccount != null) ...[
                  const SizedBox(height: 16),
                  _buildDeleteAccountButton(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).textTheme.bodySmall?.color,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onLogout,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 22,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'تسجيل الخروج',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onDeleteAccount,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'حذف الحساب',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
