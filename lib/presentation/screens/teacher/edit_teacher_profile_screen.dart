import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/services/teacher_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';
import 'package:edu_platform_app/data/services/location_service.dart';
import 'package:edu_platform_app/data/services/auth_service.dart';
import 'package:edu_platform_app/data/models/lookup_models.dart';
import 'package:edu_platform_app/presentation/widgets/custom_text_field.dart';
import 'package:edu_platform_app/presentation/widgets/primary_button.dart';

class EditTeacherProfileScreen extends StatefulWidget {
  const EditTeacherProfileScreen({super.key});

  @override
  State<EditTeacherProfileScreen> createState() =>
      _EditTeacherProfileScreenState();
}

class _EditTeacherProfileScreenState extends State<EditTeacherProfileScreen> {
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
  bool _isLoading = true;
  int _currentTeacherId = 0;

  @override
  void initState() {
    super.initState();
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
    await _fetchProfileData();
  }

  Future<void> _fetchGovernorates() async {
    final response = await _locationService.getGovernorates();
    if (response.succeeded && response.data != null) {
      if (mounted) {
        setState(() {
          _governorates = response.data!;
        });
      }
    }
  }

  Future<void> _fetchEducationStages() async {
    final response = await _authService.getEducationStages();
    if (response.succeeded && response.data != null) {
      if (mounted) {
        setState(() {
          _allEducationStages = response.data!;
        });
      }
    }
  }

  Future<void> _fetchSubjects() async {
    final response = await _authService.getSubjects();
    if (response.succeeded && response.data != null) {
      if (mounted) {
        setState(() {
          _allSubjects = response.data!;
        });
      }
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final userGuid = await _tokenService.getUserGuid();
      if (userGuid != null) {
        final response = await _teacherService.getProfileByGuid(userGuid);
        if (response.succeeded && response.data != null) {
          final data = response.data!;
          if (!mounted) return;

          setState(() {
            _currentTeacherId = data['teacherId'] ?? 0;
            _phoneController.text = data['phoneNumber'] ?? '';
            _whatsappController.text = data['whatsAppNumber'] ?? '';
            _facebookController.text = data['facebookUrl'] ?? '';
            _telegramController.text = data['telegramUrl'] ?? '';
            _youtubeController.text = data['youTubeChannelUrl'] ?? '';
            _cityController.text = data['city'] ?? '';
            _existingPhotoUrl = data['photoUrl'];

            if (data['governorate'] != null) {
              if (_governorates.contains(data['governorate'])) {
                _selectedGovernorate = data['governorate'];
              }
            }

            if (data['subjectId'] != null) {
              _selectedSubjectId = data['subjectId'];
            } else if (data['subject'] != null &&
                data['subject']['id'] != null) {
              _selectedSubjectId = data['subject']['id'];
            }

            _selectedStageIds.clear();
            if (data['educationStageIds'] != null) {
              _selectedStageIds.addAll(
                List<int>.from(data['educationStageIds']),
              );
            }

            _isLoading = false;
          });

          if (_currentTeacherId != 0) {
            await _tokenService.saveTeacherId(_currentTeacherId);
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching profile data: $e');
      if (mounted) setState(() => _isLoading = false);
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

    if (_currentTeacherId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: لم يتم العثور على بيانات المعلم'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final response = await _teacherService.updateProfile(
      teacherId: _currentTeacherId,
      phoneNumber: _phoneController.text,
      governorate: _selectedGovernorate ?? '',
      city: _cityController.text,
      subjectId: _selectedSubjectId ?? 0,
      facebookUrl: _facebookController.text,
      telegramUrl: _telegramController.text,
      whatsAppNumber: _whatsappController.text,
      youTubeChannelUrl: _youtubeController.text,
      educationStageIds: _selectedStageIds,
      photoPath: _selectedImage?.path,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الملف الشخصي بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
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
          'تعديل الملف الشخصي',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
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
                      const SizedBox(height: 32),
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
                            hint: Text(
                              'المحافظة',
                              style: GoogleFonts.inter(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
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
                            hint: Text(
                              'المادة',
                              style: GoogleFonts.inter(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                            isExpanded: true,
                            dropdownColor: Theme.of(context).cardColor,
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
                            selectedColor: AppColors.primary.withOpacity(0.2),
                            checkmarkColor: AppColors.primary,
                            backgroundColor: Theme.of(context).cardColor,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'روابط التواصل الاجتماعي',
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
                        text: 'حفظ التغييرات',
                        isLoading: false,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
