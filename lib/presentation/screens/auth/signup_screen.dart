import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/auth_models.dart';
import 'package:edu_platform_app/data/models/role_model.dart';
import 'package:edu_platform_app/data/models/lookup_models.dart';
import 'package:edu_platform_app/data/services/auth_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart'; // Added
import 'package:edu_platform_app/data/services/location_service.dart'; // Added
import 'package:edu_platform_app/presentation/widgets/custom_text_field.dart';
import 'package:edu_platform_app/presentation/widgets/primary_button.dart';
import 'package:edu_platform_app/presentation/screens/shared/main_screen.dart'; // Added

import '../teacher/teacher_dashboard_screen.dart';
import '../parent/parent_dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _tokenService = TokenService(); // Added
  final _locationService = LocationService(); // Added

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  // _subjectIdController removed as we will use dropdown
  final _teacherIdController = TextEditingController();
  final _studentNumberController = TextEditingController();

  // Teacher Profile Fields
  final _phoneController = TextEditingController();
  final _facebookController = TextEditingController();
  final _telegramController = TextEditingController();
  final _whatsAppController = TextEditingController();
  final _youTubeController = TextEditingController();
  final _cityController = TextEditingController(); // Added
  String? _selectedPhotoPath;

  bool _isLoading = false;
  List<Role> _roles = [];
  List<Subject> _subjects = []; // Added
  List<EducationStage> _educationStages = []; // Added

  String? _selectedRole;
  int? _selectedSubjectId; // Added
  List<int> _selectedEducationStageIds = []; // Added
  List<String> _governorates = []; // Added
  String? _selectedGovernorate; // Added

  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _fetchRoles();
    _fetchSubjects();
    _fetchEducationStages();
    _fetchGovernorates(); // Added
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nationalIdController.dispose();
    _parentPhoneController.dispose();
    // _subjectIdController.dispose(); // Removed
    _teacherIdController.dispose();
    _studentNumberController.dispose();
    _phoneController.dispose();
    _facebookController.dispose();
    _telegramController.dispose();
    _whatsAppController.dispose();
    _youTubeController.dispose();
    _cityController.dispose(); // Added
    _backgroundController.stop();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoles() async {
    final response = await _authService.getRoles();
    if (response.succeeded && response.data != null) {
      if (!mounted) return;
      setState(() {
        _roles = response.data!
            .where((role) => role.name != 'Admin' && role.name != 'Assistant')
            .toList();
      });
    }
  }

  Future<void> _fetchSubjects() async {
    final response = await _authService.getSubjects();
    if (response.succeeded && response.data != null) {
      if (!mounted) return;
      setState(() {
        _subjects = response.data!;
      });
    }
  }

  Future<void> _fetchEducationStages() async {
    final response = await _authService.getEducationStages();
    if (response.succeeded && response.data != null) {
      if (!mounted) return;
      setState(() {
        _educationStages = response.data!;
      });
    }
  }

  Future<void> _fetchGovernorates() async {
    final response = await _locationService.getGovernorates();
    if (response.succeeded && response.data != null) {
      if (!mounted) return;
      setState(() {
        _governorates = response.data!;
      });
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      setState(() {
        _selectedPhotoPath = result.files.single.path!;
      });
    }
  }

  Future<void> _handleSignup() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      _showErrorDialog('الرجاء اختيار نوع الحساب');
      return;
    }

    setState(() => _isLoading = true);

    // Prepend +20 to WhatsApp number if not empty and doesn't start with +
    if (_whatsAppController.text.isNotEmpty &&
        !_whatsAppController.text.startsWith('+')) {
      _whatsAppController.text = '+20${_whatsAppController.text}';
    }

    final request = SignupRequest(
      email: _emailController.text,
      password: _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      role: _selectedRole!,
      nationalId: null,
      gradeYear: 0,
      parentPhoneNumber: _selectedRole == 'Parent'
          ? _nationalIdController.text
          : _parentPhoneController.text,
      subjectId: _selectedSubjectId,
      teacherId: int.tryParse(_teacherIdController.text) ?? 0,
      educationStageIds: _selectedEducationStageIds,
      phoneNumber: _phoneController.text,
      facebookUrl: _facebookController.text,
      telegramUrl: _telegramController.text,
      whatsAppNumber: _whatsAppController.text,
      youTubeChannelUrl: _youTubeController.text,
      photoPath: _selectedPhotoPath,
      studentNumber: _selectedRole == 'Student'
          ? _studentNumberController.text
          : null,
      governorate: _selectedGovernorate, // Added
      city: _cityController.text.isNotEmpty
          ? _cityController.text
          : null, // Added
    );

    final response = await _authService.signup(request);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.succeeded && response.data != null) {
      await _tokenService.saveToken(response.data!.token);
      await _tokenService.saveRefreshToken(response.data!.refreshToken);

      if (response.data!.userId != null) {
        await _tokenService.saveUserId(response.data!.userId!);
      }
      await _tokenService.saveUserGuid(response.data!.id);

      await _tokenService.saveUserInfo(
        name: '${response.data!.firstName} ${response.data!.lastName}',
        email: response.data!.email,
      );

      await _tokenService.saveExtendedUserInfo(
        photoUrl: response.data!.photoUrl,
        phoneNumber: response.data!.phoneNumber,
        facebookUrl: response.data!.facebookUrl,
        telegramUrl: response.data!.telegramUrl,
        whatsAppNumber: response.data!.whatsAppNumber,
        youTubeChannelUrl: response.data!.youTubeChannelUrl,
      );

      // Save Role
      final roles = response.data!.roles;
      if (roles.isNotEmpty) {
        String roleToSave = roles.first;
        if (roles.contains('Teacher')) roleToSave = 'Teacher';
        if (roles.contains('Student')) roleToSave = 'Student';
        await _tokenService.saveRole(roleToSave);
      }

      _showSnackBar('تم إنشاء الحساب بنجاح!');

      // Navigate based on role
      if (roles.contains('Student')) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else if (roles.contains('Teacher')) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const TeacherDashboardScreen(),
          ),
          (route) => false,
        );
      } else if (roles.contains('Parent')) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ParentDashboardScreen(),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } else {
      String errorMessage;
      if (response.errors != null && response.errors!.isNotEmpty) {
        errorMessage = response.errors!
            .map((e) => '• ${_translateError(e)}')
            .join('\n');
      } else {
        errorMessage = _translateError(response.message);
      }
      _showErrorDialog(errorMessage);
    }
  }

  String _translateError(String error) {
    if (error.contains("is already taken"))
      return "هذا البريد الإلكتروني أو الاسم مستخدم بالفعل";
    if (error.contains("Password must be at least"))
      return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
    if (error.contains(
      "Passwords must have at least one non alphanumeric character",
    ))
      return "كلمة المرور يجب أن تحتوي على رمز خاص واحد على الأقل";
    if (error.contains("Passwords must have at least one digit"))
      return "كلمة المرور يجب أن تحتوي على رقم واحد على الأقل";
    if (error.contains("Passwords must have at least one uppercase"))
      return "كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل";
    if (error.contains("Incorrect password")) return "كلمة المرور غير صحيحة";
    if (error.contains("User not found")) return "المستخدم غير موجود";
    if (error.contains("Invalid email")) return "البريد الإلكتروني غير صحيح";
    if (error.contains("Failure")) return "حدث خطأ في العملية";

    return error;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'تنبيه',
              style: GoogleFonts.outfit(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            textAlign: TextAlign.start,
            style: GoogleFonts.inter(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 14,
              height: 1.5,
            ),
          ),
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(size),

          // Decorative Orbs
          _buildDecorativeOrbs(size),

          // Content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  pinned: true,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  expandedHeight: 200,
                  flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
                ),

                // Form Content
                SliverToBoxAdapter(child: _buildForm()),
              ],
            ),
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
        // Top Right Red Orb
        Positioned(
          top: -size.height * 0.1,
          right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.6,
            height: size.width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.15),
                  Theme.of(context).primaryColor.withOpacity(0),
                ],
              ),
            ),
          ),
        ),

        // Bottom Left Dark Red Orb
        Positioned(
          bottom: size.height * 0.2,
          left: -size.width * 0.3,
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
        child: FadeInDown(
          duration: const Duration(milliseconds: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).cardColor.withOpacity(0.5),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Image.asset(
                  'assets/images/logo_icon.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'إنشاء حساب',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'منصة بوصلة - Bosla',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'أنشئ حساباً لبدء رحلتك التعليمية',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              _buildSectionHeader(
                'المعلومات الشخصية',
                Icons.person_outline_rounded,
              ),
              const SizedBox(height: 20),

              // Name Fields
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _firstNameController,
                      hintText: 'الاسم الأول',
                      prefixIcon: Icons.badge_outlined,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _lastNameController,
                      hintText: 'اسم العائلة',
                      prefixIcon: Icons.badge_outlined,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section Header
              _buildSectionHeader('تفاصيل الحساب', Icons.lock_outline_rounded),
              const SizedBox(height: 20),

              CustomTextField(
                controller: _emailController,
                hintText: 'البريد الإلكتروني',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.isEmpty) return 'مطلوب';
                  if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _passwordController,
                hintText: 'كلمة المرور',
                prefixIcon: Icons.lock_outlined,
                isPassword: true,
                validator: (v) {
                  if (v!.isEmpty) return 'مطلوب';
                  if (v.length < 6) return 'الحد الأدنى 6 أحرف';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Section Header
              _buildSectionHeader('اختيار نوع الحساب', Icons.school_outlined),
              const SizedBox(height: 20),

              // Role Dropdown
              _buildRoleDropdown(),

              // Role Specific Fields
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Column(
                  children: [
                    if (_selectedRole == 'Student') ...[
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _studentNumberController,
                        hintText: 'رقم الطالب',
                        prefixIcon: Icons.perm_identity_rounded,
                        keyboardType: TextInputType.text,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _parentPhoneController,
                        hintText: 'رقم هاتف ولي الأمر',
                        prefixIcon: Icons.phone_android_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildGovernorateDropdown(),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _cityController,
                        hintText: 'المدينة',
                        prefixIcon: Icons.location_city_rounded,
                        keyboardType: TextInputType.text,
                        validator: (v) => null, // Optional
                      ),
                    ],
                    if (_selectedRole == 'Teacher') ...[
                      _buildSubjectDropdown(),
                      const SizedBox(height: 16),
                      _buildEducationStageSelector(),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _phoneController,
                        hintText: 'رقم الهاتف',
                        prefixIcon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _whatsAppController,
                        hintText: 'رقم الواتساب',
                        prefixIcon: Icons.chat_rounded,
                        keyboardType: TextInputType.phone,
                        prefixText: '+20 ',
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _facebookController,
                        hintText: 'رابط فيسبوك',
                        prefixIcon: Icons.facebook_rounded,
                        keyboardType: TextInputType.url,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _telegramController,
                        hintText: 'رابط تيليجرام',
                        prefixIcon: Icons.send_rounded,
                        keyboardType: TextInputType.url,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _youTubeController,
                        hintText: 'رابط قناة اليوتيوب',
                        prefixIcon: Icons.video_library_rounded,
                        keyboardType: TextInputType.url,
                        validator: (v) => null, // Optional
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: Theme.of(context).iconTheme.color,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedPhotoPath != null
                                      ? _selectedPhotoPath!
                                            .split(Platform.pathSeparator)
                                            .last
                                      : 'تحميل صورة الملف الشخصي',
                                  style: GoogleFonts.inter(
                                    color: _selectedPhotoPath != null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedPhotoPath != null)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildGovernorateDropdown(),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _cityController,
                        hintText: 'المدينة',
                        prefixIcon: Icons.location_city_rounded,
                        keyboardType: TextInputType.text,
                        validator: (v) => null, // Optional
                      ),
                    ],
                    if (_selectedRole == 'Parent') ...[
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _nationalIdController,
                        hintText: 'رقم الهاتف مطابق مع رقم الابن/ة',
                        prefixIcon: Icons.phone_iphone_rounded,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ],
                    if (_selectedRole == 'Assistant') ...[
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _teacherIdController,
                        hintText: 'معرف المعلم',
                        prefixIcon: Icons.person_search_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Sign Up Button
              PrimaryButton(
                onPressed: _handleSignup,
                text: 'إنشاء حساب',
                isLoading: _isLoading,
                icon: Icons.person_add_rounded,
              ),

              const SizedBox(height: 24),

              // Sign In Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'لديك حساب بالفعل؟ ',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'تسجيل الدخول',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          dropdownColor: Theme.of(context).cardColor,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          hint: Row(
            children: [
              Icon(
                Icons.person_search_outlined,
                color: Theme.of(context).iconTheme.color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'اختر نوع الحساب',
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          value: _selectedRole,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Theme.of(context).iconTheme.color,
          ),
          // Ensure dropdown button uses full width
          isExpanded: true,
          items: _roles.map((role) {
            return DropdownMenuItem(
              value: role.name,
              child: Row(
                children: [
                  Icon(
                    _getRoleIcon(role.name),
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    role.name,
                    style: GoogleFonts.inter(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedRole = value;
            });
          },
          validator: (v) => v == null ? 'الرجاء اختيار نوع الحساب' : null,
        ),
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Student':
        return Icons.school_rounded;
      case 'Teacher':
        return Icons.menu_book_rounded;
      case 'Parent':
        return Icons.family_restroom_rounded;
      case 'Assistant':
        return Icons.support_agent_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Widget _buildSubjectDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          dropdownColor: Theme.of(context).cardColor,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          hint: Row(
            children: [
              Icon(
                Icons.book_outlined,
                color: Theme.of(context).iconTheme.color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'اختر المادة',
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          value: _selectedSubjectId,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Theme.of(context).iconTheme.color,
          ),
          items: _subjects.map((subject) {
            return DropdownMenuItem(
              value: subject.id,
              child: Text(
                subject.name,
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSubjectId = value;
            });
          },
          validator: (v) => v == null ? 'الرجاء اختيار مادة' : null,
        ),
      ),
    );
  }

  Widget _buildEducationStageSelector() {
    final selectedCount = _selectedEducationStageIds.length;
    final text = selectedCount > 0
        ? 'تم اختيار $selectedCount'
        : 'اختر المراحل الدراسية';

    return GestureDetector(
      onTap: _showEducationStagesDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.school_outlined,
              color: Theme.of(context).iconTheme.color,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: selectedCount > 0
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: Theme.of(context).iconTheme.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGovernorateDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          dropdownColor: Theme.of(context).cardColor,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          hint: Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Theme.of(context).iconTheme.color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'اختر المحافظة',
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          value: _selectedGovernorate,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Theme.of(context).iconTheme.color,
          ),
          isExpanded: true,
          items: _governorates.map((governorate) {
            return DropdownMenuItem(
              value: governorate,
              child: Text(
                governorate,
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedGovernorate = value;
            });
          },
          validator: (v) => null, // Optional
        ),
      ),
    );
  }

  void _showEducationStagesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                'اختر المراحل الدراسية',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _educationStages.map((stage) {
                    final isSelected = _selectedEducationStageIds.contains(
                      stage.id,
                    );
                    return CheckboxListTile(
                      title: Text(
                        stage.name,
                        style: GoogleFonts.inter(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      value: isSelected,
                      activeColor: Theme.of(context).primaryColor,
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            _selectedEducationStageIds.add(stage.id);
                          } else {
                            _selectedEducationStageIds.remove(stage.id);
                          }
                        });
                        // Also update parent state to reflect count change
                        this.setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'تم',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
