import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/subject_service.dart';
import 'package:edu_platform_app/data/services/course_service.dart';
import 'package:edu_platform_app/data/models/course_models.dart';
import '../shared/course_details/course_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_platform_app/core/constants/app_constants.dart';
import 'package:edu_platform_app/data/services/subscription_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';

class StudentCoursesScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;
  final int educationStageId;

  const StudentCoursesScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.educationStageId,
  });

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final _subjectService = SubjectService();
  final _courseService = CourseService();
  final _subscriptionService = SubscriptionService();
  final _tokenService = TokenService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _teachersWithCourses = [];
  String? _error;
  Set<int> _subscribedCourseIds = {};
  Set<int> _pendingCourseIds = {};

  @override
  void initState() {
    super.initState();
    _fetchCourses();
    _checkStudentSubscriptions();
  }

  Future<void> _checkStudentSubscriptions() async {
    final studentId = await _tokenService.getUserId();
    if (studentId == null) return;

    final response =
        await _subscriptionService.getStudentSubscriptions(studentId);
    if (mounted && response.succeeded && response.data != null) {
      setState(() {
        _subscribedCourseIds = response.data!
            .where((sub) => sub.status == 'Approved')
            .map((sub) => sub.courseId)
            .toSet();
        _pendingCourseIds = response.data!
            .where((sub) => sub.status == 'Pending')
            .map((sub) => sub.courseId)
            .toSet();
      });
    }
  }

  Future<void> _fetchCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _subjectService.getTeachersByEducationStage(
      widget.educationStageId,
      widget.subjectId,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.succeeded && response.data != null) {
          _teachersWithCourses = response.data!;
          for (var teacher in _teachersWithCourses) {
            if (teacher['courses'] != null) {
              (teacher['courses'] as List)
                  .sort((a, b) => (a['index'] ?? 0).compareTo(b['index'] ?? 0));
            }
          }
        } else {
          _error = response.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).iconTheme.color,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          widget.subjectName,
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background container removed to use Scaffold background
          Container(color: Theme.of(context).scaffoldBackgroundColor),

          // Subtle Red Glow (Static)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWhatsApp,
        backgroundColor: const Color(0xFF25D366), // WhatsApp Green
        elevation: 4,
        child: const Icon(Icons.mark_chat_unread_rounded, color: Colors.white),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    const phoneNumber = '+201012345678'; // Replace with actual number
    final uri = Uri.parse('https://wa.me/$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح واتساب'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_teachersWithCourses.isEmpty) return _buildEmptyState();

    return _buildContent();
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _fetchCourses,
      color: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final teacherData = _teachersWithCourses[index];
              final teacherName = teacherData['fullName'] ?? 'معلم غير معروف';
              final courses = teacherData['courses'] as List? ?? [];

              if (courses.isEmpty) return const SizedBox.shrink();

              return FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: Duration(milliseconds: 100 * index),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher Section Title
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30, // vertical line
                            height: 2,
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.5),
                          ),
                          const SizedBox(width: 10),
                          Builder(
                            builder: (context) {
                              String? imageUrl;
                              final profile = teacherData['teacherProfile'];
                              if (profile is String) {
                                imageUrl = profile;
                              } else if (profile is Map &&
                                  profile['photoUrl'] != null) {
                                imageUrl = profile['photoUrl'];
                              }
                              imageUrl ??= teacherData['photoUrl'];

                              if (imageUrl != null && imageUrl.isNotEmpty) {
                                return CircleAvatar(
                                  radius: 16,
                                  backgroundImage: NetworkImage(imageUrl),
                                  backgroundColor: Theme.of(context).cardColor,
                                );
                              }
                              return CircleAvatar(
                                radius: 16,
                                backgroundColor: Theme.of(context).cardColor,
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).iconTheme.color?.withOpacity(0.7),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Text(
                            teacherName,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).textTheme.titleMedium?.color?.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Courses List for this Teacher
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 600) {
                            // Tablet/Desktop: Grid Layout using Wrap
                            final int crossAxisCount =
                                constraints.maxWidth > 900 ? 3 : 2;
                            final double spacing = 16;
                            final double width = (constraints.maxWidth -
                                    (spacing * (crossAxisCount - 1))) /
                                crossAxisCount;

                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: courses.map((course) {
                                return SizedBox(
                                  width: width,
                                  child: _buildCourseTile(
                                    course,
                                    teacherName,
                                    teacherData['id'],
                                    teacherData['whatAppNumber'],
                                  ),
                                );
                              }).toList(),
                            );
                          }

                          // Mobile: Vertical List
                          return Column(
                            children: courses
                                .map(
                                  (course) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildCourseTile(
                                      course,
                                      teacherName,
                                      teacherData['id'],
                                      teacherData['whatAppNumber'],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            }, childCount: _teachersWithCourses.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            ),
            child: Text(
              '${_teachersWithCourses.fold(0, (sum, teacher) => sum + (teacher['courses'] as List).length)} دورات',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'استكشف أفضل\nالمعلمين والدورات',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineMedium?.color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTile(
    dynamic course,
    String teacherName,
    dynamic teacherId,
    String? whatsAppNumber,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String? imageUrl = course['courseImageUrl'];

    return GestureDetector(
      onTap: () {
        final courseMap = Map<String, dynamic>.from(course);
        courseMap['teacherName'] = teacherName;
        courseMap['teacherId'] = teacherId;

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
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).cardColor,
          border: Border.all(
            color:
                Theme.of(context).dividerColor.withOpacity(isDark ? 0.1 : 0.5),
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
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
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
                      course['title'] ?? 'دورة بدون عنوان',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        height: 1.2,
                      ),
                    ),
                    if ((course['description'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        course['description'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          height: 1.4,
                        ),
                      ),
                    ],
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

                              if (discountedPrice > 0 &&
                                  discountedPrice < price) {
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
                        if (_subscribedCourseIds.contains(course['id']))
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
                          )
                        else if (_pendingCourseIds.contains(course['id']))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'في انتظار الموافقة',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              if (whatsAppNumber != null &&
                                  whatsAppNumber.isNotEmpty)
                                _buildActionButton(
                                  icon: FontAwesomeIcons.whatsapp,
                                  color: const Color(0xFF25D366),
                                  onTap: () async {
                                    final uri = Uri.parse(
                                        'https://wa.me/$whatsAppNumber');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  isFA: true,
                                ),
                              const SizedBox(width: 8),
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
                                      color: isDark
                                          ? Colors.transparent
                                          : Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(context).primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          AppConstants.data
                                              ? Icons.add_rounded
                                              : Icons.person_add_rounded,
                                          color: isDark
                                              ? Colors.white
                                              : Theme.of(context).primaryColor,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppConstants.data
                                              ? 'إشتراك'
                                              : 'إنضم إلينا',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Theme.of(context).primaryColor,
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
          size: 40,
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required dynamic icon,
    required Color color,
    required VoidCallback onTap,
    bool isFA = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Center(
            child: isFA
                ? FaIcon(icon as IconData, color: color, size: 20)
                : Icon(icon as IconData, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  Future<void> _subscribeToCourse(int courseId) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      ),
    );

    final response = await _courseService.subscribeToCourse(courseId: courseId);

    // Hide loading indicator
    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // Correctly pop the dialog
    }

    if (mounted) {
      if (response.succeeded) {
        setState(() {
          _pendingCourseIds.add(courseId);
        });
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

  // --- Reused UI Components ---

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            _error ?? 'خطأ',
            style: GoogleFonts.inter(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchCourses,
            child: const Text('حاول مرة أخرى'),
          ),
        ],
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
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد كورسات لهذه المرحلة الآن',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم إضافة كورسات قريباً',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
