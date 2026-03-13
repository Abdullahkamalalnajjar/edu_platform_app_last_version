import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/core/constants/app_constants.dart';
import 'package:edu_platform_app/data/models/course_models.dart';
import 'package:edu_platform_app/data/services/course_service.dart';
import 'package:edu_platform_app/data/services/subscription_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/data/services/settings_service.dart';
import '../shared/course_details/course_details_screen.dart';

class TeacherCoursesScreen extends StatefulWidget {
  final int teacherId;
  final String teacherName;
  final Map<String, dynamic> teacherData;

  const TeacherCoursesScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.teacherData,
  });

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen>
    with SingleTickerProviderStateMixin {
  final _courseService = CourseService();
  final _subscriptionService = SubscriptionService();
  final _tokenService = TokenService();
  late AnimationController _backgroundController;
  List<Map<String, dynamic>> _allCourses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  List<Map<String, dynamic>> _teacherStages = [];
  int? _selectedStageId;
  bool _isLoading = false;
  Set<int> _subscribedCourseIds = {}; // Track subscribed courses

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Extract stages from passed data
    final stages = widget.teacherData['teacherEducationStages'] as List? ?? [];
    _teacherStages = List<Map<String, dynamic>>.from(
      stages.map((s) => Map<String, dynamic>.from(s)),
    );

    // Check if a specific stage was pre-selected (coming from SelectGradeScreen)
    final preSelectedStageId = widget.teacherData['selectedStageId'];
    if (preSelectedStageId != null) {
      _selectedStageId = preSelectedStageId;
    } else if (_teacherStages.isNotEmpty) {
      // Initial stage selection (default to first)
      _selectedStageId = _teacherStages.first['id'];
    }

    _fetchCourses();
    _checkStudentSubscriptions();
    _updateConfig();
  }

  Future<void> _updateConfig() async {
    final settingsService = SettingsService();
    final response = await settingsService.getIconPricerEnabled();
    if (mounted && response.succeeded && response.data != null) {
      if (AppConstants.data != response.data) {
        setState(() {
          AppConstants.data = response.data!;
        });
      }
    }
  }

  Future<void> _checkStudentSubscriptions() async {
    final studentId = await _tokenService.getUserId();
    if (studentId == null) return;

    // Get all approved subscriptions for this student
    final approvedResponse = await _subscriptionService.getStudentSubscriptions(
      studentId,
    );

    if (mounted &&
        approvedResponse.succeeded &&
        approvedResponse.data != null) {
      setState(() {
        _subscribedCourseIds = approvedResponse.data!
            .where((sub) => sub.status == 'Approved')
            .map((sub) => sub.courseId)
            .toSet();
      });
    }
  }

  Future<void> _fetchCourses() async {
    setState(() => _isLoading = true);
    final response = await _courseService.getCoursesByTeacher(widget.teacherId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.succeeded && response.data != null) {
          _allCourses = response.data!;

          // Merge images from passed teacherData if missing in fetched courses
          try {
            final passedCourses = widget.teacherData['courses'] as List? ?? [];
            if (passedCourses.isNotEmpty) {
              for (var course in _allCourses) {
                if (course['courseImageUrl'] == null ||
                    course['courseImageUrl'].toString().isEmpty) {
                  final match = passedCourses.firstWhere(
                    (pc) => pc['id'] == course['id'],
                    orElse: () => null,
                  );
                  if (match != null && match['courseImageUrl'] != null) {
                    course['courseImageUrl'] = match['courseImageUrl'];
                  }
                }
              }
            }
          } catch (e) {
            print('Error merging images: $e');
          }

          // Check if we have a pre-selected stage from SelectGradeScreen
          final preSelectedStageId = widget.teacherData['selectedStageId'];

          // Extract unique stages from the actual courses to ensure IDs match
          final uniqueStages = <int, Map<String, dynamic>>{};
          for (var course in _allCourses) {
            final stageId = course['educationStageId'];
            final stageName = course['educationStageName'];
            if (stageId != null) {
              uniqueStages[stageId] = {
                'id': stageId,
                'educationStageName': stageName ?? 'مرحلة غير معروفة',
              };
            }
          }

          // Update stages list only if we don't have them from teacherData
          if (_teacherStages.isEmpty && uniqueStages.isNotEmpty) {
            _teacherStages = uniqueStages.values.toList();
          }

          // If we have a pre-selected stage, ALWAYS use it
          if (preSelectedStageId != null) {
            // Ensure types match (parser)
            if (preSelectedStageId is String) {
              _selectedStageId = int.tryParse(preSelectedStageId);
            } else {
              _selectedStageId = preSelectedStageId;
            }
          }
          // Otherwise, if no selection or invalid selection, pick first available
          else if (_selectedStageId == null ||
              !_teacherStages.any((s) => s['id'] == _selectedStageId)) {
            if (_teacherStages.isNotEmpty) {
              _selectedStageId = _teacherStages.first['id'];
            }
          }

          // Apply filter - ALWAYS filter by selected stage
          if (_selectedStageId != null) {
            _filteredCourses = _allCourses.where((c) {
              final rawId = c['educationStageId'] ?? c['gradeYear'];
              if (rawId == null) return false;
              return rawId.toString() == _selectedStageId.toString();
            }).toList();
          } else {
            _filteredCourses = List.from(_allCourses);
          }
        }
      });
    }
  }

  void _selectStage(int stageId) {
    setState(() {
      _selectedStageId = stageId;
      _filteredCourses = _allCourses.where((course) {
        final rawId = course['educationStageId'] ?? course['gradeYear'];
        if (rawId == null) return false;
        return rawId.toString() == stageId.toString();
      }).toList();
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _subscribeToCourse(int courseId) async {
    setState(() => _isLoading = true);

    final response = await _courseService.subscribeToCourse(courseId: courseId);

    if (mounted) {
      setState(() => _isLoading = false);

      if (mounted && context.mounted) {
        if (response.succeeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('في انتظار قبول المدرس'),
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
  }

  Future<void> _openWhatsApp(String? whatsAppNumber) async {
    if (whatsAppNumber == null || whatsAppNumber.isEmpty) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم الواتساب غير متوفر'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse('https://wa.me/$whatsAppNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح واتساب'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final whatsAppNumber = widget.teacherData['whatsAppNumber'];

    return Scaffold(
      // ... existing scaffold properties ...
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // ... existing app bar ...
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
          _buildAnimatedBackground(size),
          _buildDecorativeOrbs(size),
          SafeArea(child: _buildBody()),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
      floatingActionButton: whatsAppNumber != null && whatsAppNumber.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _openWhatsApp(whatsAppNumber),
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(
                Icons.mark_chat_unread_rounded,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    // Check if we have stages to show selector, otherwise just verify courses
    // logic: always show content structure, maybe usage empty state inside
    return _buildContent();
  }

  Widget _buildContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Teacher Info Header
        SliverToBoxAdapter(child: _buildTeacherHeader()),

        // Stage Selector
        if (_teacherStages.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _teacherStages.map((stage) {
                    final isSelected = stage['id'] == _selectedStageId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _selectStage(stage['id']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.glassBorder,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            stage['educationStageName'] ?? '',
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

        SliverToBoxAdapter(child: _buildCoursesHeader()),

        // Courses List
        if (_filteredCourses.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final course = _filteredCourses[index];
                return FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  delay: Duration(milliseconds: 100 * index),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildCourseTile(course, index),
                  ),
                );
              }, childCount: _filteredCourses.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildTeacherHeader() {
    final photoUrl = widget.teacherData['photoUrl'];
    final subjectName = widget.teacherData['subjectName'] ?? '';
    final educationStages =
        widget.teacherData['teacherEducationStages'] as List? ?? [];
    final phoneNumber = widget.teacherData['phoneNumber'];
    final facebookUrl = widget.teacherData['facebookUrl'];
    final telegramUrl = widget.teacherData['telegramUrl'];
    final whatsAppNumber = widget.teacherData['whatsAppNumber'];
    final youTubeUrl = widget.teacherData['youTubeUrl'];

    String stagesText = '';
    if (educationStages.isNotEmpty) {
      stagesText = educationStages
          .map((stage) => stage['educationStageName'] ?? '')
          .where((name) => name.isNotEmpty)
          .join(' • ');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Teacher Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      AppColors.primary.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Teacher Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.teacherName,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (subjectName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subjectName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (stagesText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        stagesText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Social Links
          if ((phoneNumber != null && phoneNumber.isNotEmpty) ||
              (facebookUrl != null && facebookUrl.isNotEmpty) ||
              (telegramUrl != null && telegramUrl.isNotEmpty) ||
              (whatsAppNumber != null && whatsAppNumber.isNotEmpty) ||
              (youTubeUrl != null && youTubeUrl.isNotEmpty)) ...[
            const SizedBox(height: 20),
            Divider(color: AppColors.glassBorder),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (phoneNumber != null && phoneNumber.isNotEmpty)
                  _buildSocialButton(
                    Icons.phone_rounded,
                    Colors.blue,
                    () async {
                      final uri = Uri.parse('tel:$phoneNumber');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                if (whatsAppNumber != null && whatsAppNumber.isNotEmpty)
                  _buildSocialButton(
                    FontAwesomeIcons.whatsapp,
                    const Color(0xFF25D366),
                    () => _openWhatsApp(whatsAppNumber),
                    isFontAwesome: true,
                  ),
                if (facebookUrl != null && facebookUrl.isNotEmpty)
                  _buildSocialButton(
                    FontAwesomeIcons.facebook,
                    const Color(0xFF1877F2),
                    () async {
                      final uri = Uri.parse(facebookUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    isFontAwesome: true,
                  ),
                if (telegramUrl != null && telegramUrl.isNotEmpty)
                  _buildSocialButton(
                    FontAwesomeIcons.telegram,
                    const Color(0xFF0088CC),
                    () async {
                      final uri = Uri.parse(telegramUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    isFontAwesome: true,
                  ),
                if (youTubeUrl != null && youTubeUrl.isNotEmpty)
                  _buildSocialButton(
                    FontAwesomeIcons.youtube,
                    const Color(0xFFFF0000),
                    () async {
                      final uri = Uri.parse(youTubeUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    isFontAwesome: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialButton(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isFontAwesome = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: isFontAwesome
            ? FaIcon(icon, color: color, size: 20)
            : Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildCoursesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عرض',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'الدورات المتاحة',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.displaySmall?.color,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              '${_filteredCourses.length}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTile(Map<String, dynamic> course, int index) {
    final title = course['title'] ?? 'دورة بدون عنوان';
    final lectures = course['lectures'] as List? ?? [];
    final courseImage = course['courseImageUrl'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final courseMap = Map<String, dynamic>.from(course);
        courseMap['teacherName'] = widget.teacherName;
        courseMap['teacherId'] = widget.teacherId;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CourseDetailsScreen(course: Course.fromJson(courseMap)),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.1 : 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image Section (Pure Image, No Text)
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: (courseImage != null && courseImage.toString().isNotEmpty)
                    ? Image.network(
                        courseImage.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),

              // 2. Info Section (Below Image)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Stats Row (Lectures)
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${lectures.length} محاضرة',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price section
                        if (AppConstants.data)
                          Builder(
                            builder: (context) {
                              final price = (course['price'] ?? 0).toDouble();
                              final discountedPrice =
                                  (course['discountedPrice'] ?? 0).toDouble();

                              if (price <= 0) return const SizedBox.shrink();

                              if (discountedPrice > 0 && discountedPrice < price) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${discountedPrice.toStringAsFixed(0)} ج.م',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    Text(
                                      '${price.toStringAsFixed(0)} ج.م',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Text(
                                '${price.toStringAsFixed(0)} ج.م',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              );
                            },
                          ),

                        // Action Buttons
                        if (!_subscribedCourseIds.contains(course['id']))
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _subscribeToCourse(course['id']),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppConstants.data
                                          ? Icons.add_rounded
                                          : Icons.person_add_rounded,
                                      color: Theme.of(context).primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppConstants.data ? 'اشتراك' : 'انضم الينا',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: AppColors.success,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'تم الاشتراك',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Center(
        child: Icon(
          Icons.book_rounded,
          size: 48,
          color: Theme.of(context).primaryColor.withOpacity(0.2),
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
            Icons.videocam_off_rounded,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "لا توجد دورات متاحة لهذا المعلم",
            style: GoogleFonts.inter(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(Size size) {
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
          top: -size.height * 0.1,
          right: -size.width * 0.2,
          child: AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  20 * math.sin(_backgroundController.value * 2 * math.pi),
                  20 * math.cos(_backgroundController.value * 2 * math.pi),
                ),
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.meshGold.withOpacity(0.15),
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
