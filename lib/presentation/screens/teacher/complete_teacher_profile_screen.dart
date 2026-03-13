import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/teacher_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/data/services/location_service.dart';
import 'package:edu_platform_app/data/services/auth_service.dart';
import 'package:edu_platform_app/data/services/settings_service.dart';
import 'package:edu_platform_app/data/models/lookup_models.dart';
import 'package:edu_platform_app/data/models/api_response.dart'; // Import added
import 'package:edu_platform_app/presentation/widgets/custom_text_field.dart';
import 'package:edu_platform_app/presentation/widgets/primary_button.dart';

import '../auth/login_screen.dart';

class CompleteTeacherProfileScreen extends StatefulWidget {
  final int?
  userId; // This is the User ID, but we might need Teacher ID if it exists or use 0 as per screenshot
  final int? teacherId;

  const CompleteTeacherProfileScreen({super.key, this.userId, this.teacherId});

  @override
  State<CompleteTeacherProfileScreen> createState() =>
      _CompleteTeacherProfileScreenState();
}

class _CompleteTeacherProfileScreenState
    extends State<CompleteTeacherProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teacherService = TeacherService();
  final _locationService = LocationService();
  final _authService = AuthService();
  final _tokenService = TokenService();
  final _imagePicker = ImagePicker();

  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _telegramController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _cityController = TextEditingController();

  String? _selectedGovernorate;
  List<String> _governorates = [];

  List<EducationStage> _allEducationStages = [];
  final List<int> _selectedStageIds = [];

  List<Subject> _allSubjects = [];
  int? _selectedSubjectId;

  File? _selectedImage;
  String? _existingPhotoUrl;
  bool _isLoading = false;

  int _currentTeacherId = 0;

  @override
  void initState() {
    super.initState();
    _currentTeacherId = widget.teacherId ?? 0;
    _initData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _telegramController.dispose();
    _youtubeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await Future.wait([
      _fetchGovernorates(),
      _fetchEducationStages(),
      _fetchSubjects(),
    ]);
    if (widget.teacherId != null && widget.teacherId! > 0) {
      await _populateExistingData();
    }
  }

  Future<void> _populateExistingData() async {
    // 1. Try to fetch from server first
    try {
      final userGuid = await _tokenService.getUserGuid();
      if (userGuid != null) {
        final response = await _teacherService.getProfileByGuid(userGuid);
        if (response.succeeded && response.data != null) {
          final data = response.data!;
          if (!mounted) return;
          setState(() {
            _phoneController.text = data['phoneNumber'] ?? '';
            _whatsappController.text = data['whatsAppNumber'] ?? '';
            _facebookController.text = data['facebookUrl'] ?? '';
            _telegramController.text = data['telegramUrl'] ?? '';
            _youtubeController.text = data['youTubeChannelUrl'] ?? '';
            _cityController.text = data['city'] ?? '';

            if (data['governorate'] != null) {
              // Check if the value exists in our list, exact match required
              if (_governorates.contains(data['governorate'])) {
                _selectedGovernorate = data['governorate'];
              }
            }

            // Handle Subject
            if (data['subjectId'] != null) {
              _selectedSubjectId = data['subjectId'];
            } else if (data['subject'] != null &&
                data['subject']['id'] != null) {
              _selectedSubjectId = data['subject']['id'];
            }

            // Handle Education Stages
            _selectedStageIds.clear();
            if (data['educationStageIds'] != null) {
              _selectedStageIds.addAll(
                List<int>.from(data['educationStageIds']),
              );
            } else if (data['educationStages'] != null) {
              for (var stage in data['educationStages']) {
                if (stage is Map && stage['id'] != null) {
                  _selectedStageIds.add(stage['id']);
                } else if (stage is int) {
                  _selectedStageIds.add(stage);
                }
              }
            }

            if (data['photoUrl'] != null) {
              _existingPhotoUrl = data['photoUrl'];
            }

            // Update local teacher ID from server response to ensure we UPDATE instead of CREATE
            if (data['teacherId'] != null) {
              _currentTeacherId = data['teacherId'];
            }
          });

          // Save outside setState
          if (data['teacherId'] != null) {
            await _tokenService.saveTeacherId(data['teacherId']);
          }
          return; // Successfully populated from server
        }
      }
    } catch (e) {
      print('Error populateExistingData from server: $e');
    }

    // 2. Fallback to local storage
    final phone = await _tokenService.getPhoneNumber();
    final whatsapp = await _tokenService.getWhatsAppNumber();
    final facebook = await _tokenService.getFacebookUrl();
    final telegram = await _tokenService.getTelegramUrl();
    final youtube = await _tokenService.getYouTubeChannelUrl();

    if (!mounted) return;
    setState(() {
      if (phone != null) _phoneController.text = phone;
      if (whatsapp != null) _whatsappController.text = whatsapp;
      if (facebook != null) _facebookController.text = facebook;
      if (telegram != null) _telegramController.text = telegram;
      if (youtube != null) _youtubeController.text = youtube;
    });
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

  Future<void> _fetchEducationStages() async {
    final response = await _authService.getEducationStages();
    if (response.succeeded && response.data != null) {
      if (!mounted) return;
      setState(() {
        _allEducationStages = response.data!;
      });
    }
  }

  Future<void> _fetchSubjects() async {
    final response = await _authService.getSubjects();
    if (response.succeeded && response.data != null) {
      if (!mounted) return;
      setState(() {
        _allSubjects = response.data!;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGovernorate == null) {
      _showErrorSnackBar('الرجاء اختيار المحافظة');
      return;
    }
    // For update, education stage might not be mandatory to re-select if we aren't showing pre-selected values correctly yet,
    // but for now let's keep validation.
    if (_selectedStageIds.isEmpty) {
      _showErrorSnackBar('الرجاء اختيار مرحلة دراسية واحدة على الأقل');
      return;
    }

    setState(() => _isLoading = true);

    setState(() => _isLoading = true);

    // Ensure we have the latest ID
    if (_currentTeacherId == 0) {
      _currentTeacherId = (await _tokenService.getTeacherId()) ?? 0;
    }

    ApiResponse<bool> response;

    // Check if we are updating (TeacherId > 0) or creating
    if (_currentTeacherId > 0) {
      // Update Profile (PUT)
      response = await _teacherService.updateProfile(
        teacherId: _currentTeacherId,
        phoneNumber: _phoneController.text,
        governorate: _selectedGovernorate!,
        city: _cityController.text,
        subjectId: _selectedSubjectId ?? 0, // Pass subjectId if available
        facebookUrl: _facebookController.text,
        telegramUrl: _telegramController.text,
        whatsAppNumber: _whatsappController.text,
        youTubeChannelUrl: _youtubeController.text,
        educationStageIds: _selectedStageIds,
        photoPath: _selectedImage?.path,
      );
    } else {
      // Create Profile (POST)
      final userGuid = await _tokenService.getUserGuid();
      if (userGuid == null) {
        _showErrorSnackBar('خطأ: لم يتم العثور على معرف المستخدم');
        setState(() => _isLoading = false);
        return;
      }

      if (_selectedSubjectId == null) {
        _showErrorSnackBar('الرجاء اختيار المادة');
        setState(() => _isLoading = false);
        return;
      }

      response = await _teacherService.createProfile(
        userId: userGuid,
        phoneNumber: _phoneController.text,
        governorate: _selectedGovernorate!,
        city: _cityController.text,
        subjectId: _selectedSubjectId!,
        facebookUrl: _facebookController.text,
        telegramUrl: _telegramController.text,
        whatsAppNumber: _whatsappController.text,
        youTubeChannelUrl: _youtubeController.text,
        educationStageIds: _selectedStageIds,
        photoPath: _selectedImage?.path,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.succeeded) {
      if (widget.userId != null) {
        await _tokenService.setProfileCompleted(widget.userId!);
      }

      // If it was an update, just show success and maybe go back
      if (_currentTeacherId > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعديل الملف الشخصي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh dashboard?
        Navigator.pop(context); // Go back to Settings/Dashboard
      } else {
        // Creation flow handling (Account Pending etc)
        _handleCreationSuccess();
      }
    } else {
      _showErrorSnackBar(response.message);
    }
  }

  Future<void> _handleCreationSuccess() async {
    final refreshResult = await _authService.refreshToken();
    bool isAccountDisabled = false;
    if (refreshResult.succeeded && refreshResult.data != null) {
      isAccountDisabled = refreshResult.data!.isDisable;
    }

    if (isAccountDisabled) {
      // Clear tokens immediately to prevent auto-login
      await _tokenService.clearTokens();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'في انتظار الموافقة',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'تم إنشاء ملفك الشخصي بنجاح، ولكن حسابك في انتظار موافقة المسؤول.\n\nيرجى الانتظار حتى يتم تفعيل الحساب.\n\nللاستفسار، يمكنك التواصل مع الدعم الفني.',
            style: GoogleFonts.inter(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Fetch support phone from settings API
                final settingsService = SettingsService();

                // Show loading indicator
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('جاري تحميل معلومات الدعم...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }

                final response = await settingsService.getSupportPhoneNumber();

                if (context.mounted) {
                  if (response.succeeded && response.data != null) {
                    final supportPhone = response.data!;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('رقم الدعم الفني: $supportPhone'),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'نسخ',
                          textColor: Colors.white,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: supportPhone),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ الرقم بنجاح ✓'),
                                  backgroundColor: AppColors.success,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'فشل في تحميل رقم الدعم: ${response.message}',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'التواصل مع الدعم',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: Text(
                'حسناً',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Even if account is enabled immediately (less common for teachers),
      // force re-login to ensure all claims/roles are refreshed correctly.
      if (!mounted) return;

      // Clear tokens to ensure clean login state
      await _tokenService.clearTokens();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
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

  void _toggleStage(int id) {
    setState(() {
      if (_selectedStageIds.contains(id)) {
        _selectedStageIds.remove(id);
      } else {
        _selectedStageIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          (widget.teacherId != null && widget.teacherId! > 0)
              ? 'تعديل الملف الشخصي'
              : 'استكمال ملف المعلم',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading:
            false, // Don't allow going back as it's required
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
                  child: Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                              image: _selectedImage != null
                                  ? DecorationImage(
                                      image: FileImage(_selectedImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_existingPhotoUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              _existingPhotoUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null),
                            ),
                            child:
                                (_selectedImage == null &&
                                    _existingPhotoUrl == null)
                                ? Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 40,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _phoneController,
                        hintText: 'رقم الهاتف',
                        prefixIcon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v?.isNotEmpty == true ? null : 'مطلوب',
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _whatsappController,
                        hintText: 'رقم الواتساب',
                        prefixIcon: Icons.chat_rounded,
                        keyboardType: TextInputType.phone,
                        prefixText: '+20 ',
                        validator: (v) =>
                            v?.isNotEmpty == true ? null : 'مطلوب',
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _cityController,
                        hintText: 'المدينة',
                        prefixIcon: Icons.location_city,
                        validator: (v) =>
                            v?.isNotEmpty == true ? null : 'مطلوب',
                      ),
                      const SizedBox(height: 16),

                      // Governorate Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGovernorate,
                            hint: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'المحافظة',
                                  style: GoogleFonts.inter(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                            isExpanded: true,
                            dropdownColor: Theme.of(context).cardColor,
                            items: _governorates.map((g) {
                              return DropdownMenuItem(value: g, child: Text(g));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedGovernorate = v),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Subject Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedSubjectId,
                            hint: Row(
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'المادة',
                                  style: GoogleFonts.inter(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            items: _allSubjects.map((s) {
                              return DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSubjectId = v),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Education Stages Multi-select
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المراحل الدراسية',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allEducationStages.map((stage) {
                              final isSelected = _selectedStageIds.contains(
                                stage.id,
                              );
                              return FilterChip(
                                label: Text(stage.name),
                                selected: isSelected,
                                onSelected: (_) => _toggleStage(stage.id),
                                selectedColor: AppColors.primary.withOpacity(
                                  0.2,
                                ),
                                checkmarkColor: AppColors.primary,
                                labelStyle: GoogleFonts.inter(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                backgroundColor: AppColors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.inputBorder,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'روابط التواصل الاجتماعي (اختياري)',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _facebookController,
                        hintText: 'رابط فيسبوك',
                        prefixIcon: Icons.facebook,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _telegramController,
                        hintText: 'رابط تليجرام',
                        prefixIcon: Icons.send_rounded,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _youtubeController,
                        hintText: 'رابط يوتيوب',
                        prefixIcon: Icons.video_library_rounded,
                      ),

                      const SizedBox(height: 32),

                      PrimaryButton(
                        onPressed: _handleSubmit,
                        text: 'حفظ وبدء الاستخدام',
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 32),
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
