import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:edu_platform_app/data/models/assistant_models.dart';
import 'package:edu_platform_app/data/services/assistant_service.dart';
import 'package:edu_platform_app/data/services/token_service.dart';

class ManageAssistantsScreen extends StatefulWidget {
  final int? teacherId; // Optional teacherId for admin view

  const ManageAssistantsScreen({super.key, this.teacherId});

  @override
  State<ManageAssistantsScreen> createState() => _ManageAssistantsScreenState();
}

class _ManageAssistantsScreenState extends State<ManageAssistantsScreen> {
  final _assistantService = AssistantService();
  final _tokenService = TokenService();

  List<Assistant> _assistants = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchAssistants();
  }

  Future<void> _fetchAssistants() async {
    setState(() => _isLoading = true);

    // Use widget.teacherId if provided (admin view), otherwise get from token
    int? teacherId = widget.teacherId;
    if (teacherId == null) {
      teacherId = await _tokenService.getTeacherId();
    }

    if (teacherId == null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: لم يتم العثور على معرف المعلم'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final response = await _assistantService.getTeacherAssistants(teacherId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.succeeded && response.data != null) {
          _assistants = response.data!;
        }
      });
    }
  }

  Future<void> _showAddAssistantDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'إضافة مساعد جديد',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: firstNameController,
                label: 'الاسم الأول',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: lastNameController,
                label: 'الاسم الأخير',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: emailController,
                label: 'البريد الإلكتروني',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: passwordController,
                label: 'كلمة المرور',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'إلغاء',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty ||
                  passwordController.text.isEmpty ||
                  firstNameController.text.isEmpty ||
                  lastNameController.text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى ملء جميع الحقول'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);
              await _registerAssistant(
                emailController.text,
                passwordController.text,
                firstNameController.text,
                lastNameController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'إضافة',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        prefixIcon: Icon(icon, color: AppColors.primary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Future<void> _registerAssistant(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    // Use widget.teacherId if provided (admin view), otherwise get from token
    int? teacherId = widget.teacherId;
    if (teacherId == null) {
      teacherId = await _tokenService.getTeacherId();
    }

    if (teacherId == null) return;

    final request = RegisterAssistantRequest(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      teacherId: teacherId,
    );

    final response = await _assistantService.registerAssistant(request);

    if (mounted && context.mounted) {
      if (response.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchAssistants(); // Refresh list
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

  Future<void> _deleteAssistant(Assistant assistant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف المساعد',
          style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
        content: Text(
          'هل أنت متأكد من حذف ${assistant.fullName}؟',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _assistantService.deleteAssistant(
        assistant.userId,
      );

      if (mounted && context.mounted) {
        if (response.succeeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.success,
            ),
          );
          _fetchAssistants(); // Refresh list
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

  Future<void> _showEditAssistantDialog(Assistant assistant) async {
    final emailController = TextEditingController(text: assistant.email);
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تعديل بيانات المساعد',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تعديل بيانات المساعد: ${assistant.fullName}',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: emailController,
                  label: 'البريد الإلكتروني',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: newPasswordController,
                  label: 'كلمة المرور الجديدة (اختياري)',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: confirmPasswordController,
                  label: 'تأكيد كلمة المرور',
                  icon: Icons.lock_reset_rounded,
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'إلغاء',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('البريد الإلكتروني مطلوب'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              // Validate password matching only if password field is not empty
              if (newPasswordController.text.isNotEmpty &&
                  newPasswordController.text !=
                      confirmPasswordController.text) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('كلمتا المرور غير متطابقتين'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);

              // Call service
              print(
                'Initiating edit for Assistant UserId (GUID): ${assistant.userId}',
              );

              // Only send password if user entered one
              final passwordToSend = newPasswordController.text.isNotEmpty
                  ? newPasswordController.text
                  : ''; // API might expect empty string if no change, or we might need to handle this differently depending on backend logic. Usually 'change-password' implies password change is mandatory. If the endpoint is "change-assistant-password" but effectively does update, we should check if backend allows empty password to MEAN 'no change'.
              // Based on the user request object structure:
              // { "assistantUserId": "string", "newPassword": "string", "confirmPassword": "string", "newEmail": "string" }
              // If user only wants to change email, what about passwords?
              // Assuming if we send empty passwords, backend might validate empty password.
              // Let's send what the user typed. If backend requires password always, then this UI is technically "Change Password + Optional Email Change".
              // If the user request implies we can "change email also", it might mean this endpoint is now a general update endpoint.
              // Let's pass the values.

              final response = await _assistantService.changeAssistantPassword(
                assistantUserId: assistant.userId,
                newPassword: newPasswordController.text,
                confirmPassword: confirmPasswordController.text,
                newEmail: emailController.text != assistant.email
                    ? emailController.text
                    : null,
              );

              if (mounted && context.mounted) {
                if (response.succeeded) {
                  _fetchAssistants(); // Refresh to show new email if changed
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(response.message),
                    backgroundColor: response.succeeded
                        ? AppColors.success
                        : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'حفظ التغييرات',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          'إدارة المساعدين',
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _assistants.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchAssistants,
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assistants.length,
                itemBuilder: (context, index) {
                  final assistant = _assistants[index];
                  return FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    delay: Duration(milliseconds: 100 * index),
                    child: _buildAssistantCard(assistant),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssistantDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(
          'إضافة مساعد',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantCard(Assistant assistant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          assistant.fullName,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          assistant.email,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons
                    .edit_rounded, // Changed icon to edit as it now edits email too
                color: AppColors.warning,
              ),
              onPressed: () => _showEditAssistantDialog(assistant),
              tooltip: 'تعديل البيانات',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              onPressed: () => _deleteAssistant(assistant),
              tooltip: 'حذف المساعد',
            ),
          ],
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
            Icons.people_outline_rounded,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد مساعدين',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على الزر أدناه لإضافة مساعد',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
