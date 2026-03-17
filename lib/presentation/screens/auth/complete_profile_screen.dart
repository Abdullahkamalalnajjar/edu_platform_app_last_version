import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/student_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/data/services/location_service.dart';
import 'package:edu_platform_app/data/models/api_response.dart';
import 'package:edu_platform_app/presentation/widgets/custom_text_field.dart';
import 'package:edu_platform_app/presentation/widgets/primary_button.dart';
import 'package:edu_platform_app/presentation/screens/auth/login_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  final bool isFirstLogin;
  final int? userId;
  const CompleteProfileScreen({
    super.key,
    this.isFirstLogin = false,
    this.userId,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentService = StudentService();
  final _locationService = LocationService();
  final _tokenService = TokenService();
  final _imagePicker = ImagePicker();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _cityController = TextEditingController();

  String? _selectedGovernorate;
  List<String> _governorates = [];
  bool _isLoading = false;
  int? _currentStudentId;
  File? _profileImage;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentPhoneController.dispose();
    _parentPhoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchGovernorates();
    if (!widget.isFirstLogin) {
      await _fetchProfileData();
    }
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _studentService.getProfile();
      if (response.succeeded && response.data != null) {
        final data = response.data!;
        if (!mounted) return;

        if (data.containsKey('studentId')) {
          _currentStudentId = data['studentId'];
        } else if (data.containsKey('id')) {
          _currentStudentId = data['id'];
        } else if (data.containsKey('userId')) {
          _currentStudentId = data['userId'];
        }

        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _studentPhoneController.text = data['studentPhoneNumber'] ?? '';
          _parentPhoneController.text = data['parentPhoneNumber'] ?? '';
          _cityController.text = data['city'] ?? '';
          _currentPhotoUrl =
              data['studentProfileImageUrl'];

          final gov = data['governorate'];
          // Set governorate if it exists in the list, otherwise set it anyway
          // (it will be added to dropdown when governorates load)
          if (gov != null) {
            _selectedGovernorate = gov;
            // Add to list if not present
            if (!_governorates.contains(gov)) {
              _governorates.add(gov);
            }
          }
        });
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'اختر مصدر الصورة',
            style: GoogleFonts.outfit(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: Text(
                  'المعرض',
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text(
                  'الكاميرا',
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          setState(() {
            _profileImage = File(pickedFile.path);
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackBar('فشل اختيار الصورة');
    }
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGovernorate == null) {
      _showErrorSnackBar('الرجاء اختيار المحافظة');
      return;
    }

    setState(() => _isLoading = true);

    // Try to get userId from widget params or TokenService to use as StudentId
    // If updating, ideally we send the ID. If 0, backend might deduce from Token.
    final userId = widget.userId ?? await _tokenService.getUserId();
    // Prefer fetched studentId for updates if available
    final int studentIdVal = _currentStudentId ?? userId ?? 0;

    // For Update, we might need GUID string based on recent changes
    final String? userGuid = await _tokenService.getUserGuid();

    print(
      'Submitting Profile. Int ID: $studentIdVal, GUID: $userGuid (IsFirstLogin: ${widget.isFirstLogin})',
    );

    ApiResponse<bool> response;

    if (widget.isFirstLogin) {
      // Create Profile
      response = await _studentService.createProfile(
        studentId: studentIdVal,
        gradeYear: 0,
        studentPhoneNumber: _studentPhoneController.text,
        parentPhoneNumber: _parentPhoneController.text,
        governorate: _selectedGovernorate!,
        city: _cityController.text,
      );
    } else {
      // Update Profile - Use GUID as studentId string if available, else int ID string
      response = await _studentService.updateProfile(
        studentId: userGuid ?? studentIdVal.toString(),
        gradeYear: 0,
        studentPhoneNumber: _studentPhoneController.text,
        parentPhoneNumber: _parentPhoneController.text,
        governorate: _selectedGovernorate!,
        city: _cityController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        profileImagePath: _profileImage?.path,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.succeeded) {
      if (widget.isFirstLogin) {
        // Mark profile as completed only on first login/creation
        if (userId != null) {
          await _tokenService.setProfileCompleted(userId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم استكمال البيانات بنجاح، يرجى تسجيل الدخول مرة أخرى',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        // Edit mode success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعديل الملف الشخصي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      _showErrorSnackBar(response.message);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isFirstLogin ? 'استكمال البيانات' : 'تعديل الملف الشخصي',
          style: GoogleFonts.outfit(color: AppColors.textPrimary),
        ),
        centerTitle: true,
        automaticallyImplyLeading:
            !widget.isFirstLogin, // Hide back if forced first login
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    children: [
                      // Profile Image Picker
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
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
                                margin: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: _profileImage != null
                                      ? Image.file(
                                          _profileImage!,
                                          fit: BoxFit.cover,
                                          width: 112,
                                          height: 112,
                                        )
                                      : _currentPhotoUrl != null &&
                                            _currentPhotoUrl!.isNotEmpty
                                      ? Image.network(
                                          _currentPhotoUrl!,
                                          fit: BoxFit.cover,
                                          width: 112,
                                          height: 112,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: AppColors.surfaceLight,
                                                  child: const Icon(
                                                    Icons.person_rounded,
                                                    size: 50,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                );
                                              },
                                        )
                                      : Container(
                                          color: AppColors.surfaceLight,
                                          child: const Icon(
                                            Icons.person_rounded,
                                            size: 50,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'مرحباً بك!',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يرجى استكمال بياناتك الدراسية للبدء',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _firstNameController,
                        hintText: 'الاسم الأول',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _lastNameController,
                        hintText: 'الاسم الأخير',
                        prefixIcon: Icons.person_rounded,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _studentPhoneController,
                        hintText: 'رقم الهاتف الخاص بك',
                        prefixIcon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _parentPhoneController,
                        hintText: 'رقم هاتف ولي الأمر',
                        prefixIcon: Icons.family_restroom_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),

                      // Governorate Dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGovernorate,
                            hint: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.textMuted,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'المحافظة',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            icon: const Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            items: _governorates.map((g) {
                              return DropdownMenuItem(
                                value: g,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    g,
                                    style: GoogleFonts.inter(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedGovernorate = v),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _cityController,
                        hintText: 'المدينة',
                        prefixIcon: Icons.location_city_rounded,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),

                      const SizedBox(height: 32),

                      PrimaryButton(
                        onPressed: _handleSubmit,
                        text: 'حفظ ومتابعة',
                        isLoading: _isLoading,
                        icon: Icons.check_circle_outline_rounded,
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
}
