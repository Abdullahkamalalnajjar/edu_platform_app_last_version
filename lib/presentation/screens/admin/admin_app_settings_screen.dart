import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/settings_service.dart';

class AdminAppSettingsScreen extends StatefulWidget {
  const AdminAppSettingsScreen({super.key});

  @override
  State<AdminAppSettingsScreen> createState() => _AdminAppSettingsScreenState();
}

class _AdminAppSettingsScreenState extends State<AdminAppSettingsScreen> {
  final _settingsService = SettingsService();
  final _formKey = GlobalKey<FormState>();
  final _aboutUsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _applicationUrlController = TextEditingController();
  final _versionController = TextEditingController();

  File? _selectedVideo;
  String? _videoName;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _googleIconEnabled = false; // Track Google Icon status
  bool _deleteAccountEnabled = false; // Track Delete Account status
  bool _iconPriceEnabled = false; // Track Price Icon status

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    setState(() => _isInitialLoading = true);

    try {
      // Fetch all app info from single endpoint
      final response = await _settingsService.getAppInfo();

      if (mounted && response.succeeded && response.data != null) {
        final data = response.data!;

        // Populate all fields with current data
        _aboutUsController.text = data['aboutUs'] ?? '';
        _phoneController.text = data['supportPhoneNumber'] ?? '';
        _applicationUrlController.text = data['applicationUrl'] ?? '';
        _versionController.text = data['version'] ?? '1.0.0';
        _googleIconEnabled = data['googleIconEnabled'] ?? false;
        _deleteAccountEnabled = data['btnDeleteAccountEnabled'] ?? false;
        _iconPriceEnabled = data['iconPriceEnabled'] ?? false;
      }
    } catch (e) {
      print('Error loading app info: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideo = File(result.files.single.path!);
        _videoName = result.files.single.name;
      });
    }
  }

  Future<void> _submitUpdates() async {
    if (!_formKey.currentState!.validate()) return;
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter support phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final response = await _settingsService.updateAppInfo(
      aboutUs: _aboutUsController.text,
      supportPhoneNumber: _phoneController.text,
      applicationUrl: _applicationUrlController.text.isNotEmpty
          ? _applicationUrlController.text
          : null,
      version: _versionController.text,
      explanationVideoFile: _selectedVideo,
      googleIconEnabled: _googleIconEnabled,
      deleteAccountEnabled: _deleteAccountEnabled,
      iconPriceEnabled: _iconPriceEnabled,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      print('=== UI: updateAppInfo Response ===');
      print('Succeeded: ${response.succeeded}');
      print('Message: ${response.message}');
      print('Data: ${response.data}');

      if (response.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _aboutUsController.dispose();
    _phoneController.dispose();
    _applicationUrlController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'App Settings',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: Text(
                        'Update Application Info',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // About Us Field
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About Us / من نحن',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _aboutUsController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Enter description about the app...',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter About Us text';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Support Phone Field
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support Phone Number',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: '+201000000000',
                              filled: true,
                              fillColor: AppColors.surface,
                              prefixIcon: const Icon(
                                Icons.phone_rounded,
                                color: AppColors.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter phone number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Application URL Field
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 250),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Application URL',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _applicationUrlController,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              hintText: 'https://example.com',
                              filled: true,
                              fillColor: AppColors.surface,
                              prefixIcon: const Icon(
                                Icons.link_rounded,
                                color: AppColors.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Version Field
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Version',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _versionController,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              hintText: 'e.g. 1.0.0',
                              filled: true,
                              fillColor: AppColors.surface,
                              prefixIcon: const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            // Optional validation for version
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Explanation Video Picker
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 350),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explanation Video',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickVideo,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.video_library_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedVideo != null
                                              ? 'Selected Video'
                                              : 'Choose Video File',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (_videoName != null)
                                          Text(
                                            _videoName!,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_selectedVideo != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedVideo = null;
                                          _videoName = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Google Icon Enabled Switch
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.network(
                                'https://img.icons8.com/color/48/000000/google-logo.png',
                                height: 24,
                                width: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google Sign-In Button',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Show Google login button on login screen',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _googleIconEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _googleIconEnabled = value;
                                });
                              },
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Delete Account Enabled Switch
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 420),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.delete_forever_rounded,
                                color: AppColors.error,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delete Account Button',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Show Delete Account button in settings',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _deleteAccountEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _deleteAccountEnabled = value;
                                });
                              },
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Icon Price Enabled Switch
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 440),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.monetization_on_rounded,
                                color: AppColors.success,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Price Icon Enabled',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Show Prices and Commercial content',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _iconPriceEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _iconPriceEnabled = value;
                                });
                              },
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Submit Button
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 450),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitUpdates,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.primary.withOpacity(0.3),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Update App Info',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
