import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:customer_sync/widgets/user_avatar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late bool isDark;
  XFile? _pickedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initiateSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;
    
    final newPhone = _phoneController.text.trim();
    if (newPhone != currentUser.phone) {
      // Phone changed - Verify first
      await _verifyPhoneAndSave(newPhone);
    } else {
      // No phone change - Direct update
      await _performUpdate();
    }
  }

  Future<void> _verifyPhoneAndSave(String newPhone) async {
    setState(() => _isSaving = true);
    final apiService = ref.read(apiServiceProvider);
    
    // 1. Request OTP
    final success = await apiService.requestOtp(newPhone);
    setState(() => _isSaving = false);
    
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send OTP. Please check the number.")),
        );
      }
      return;
    }

    // 2. Show OTP Dialog
    if (mounted) {
      _showOtpDialog(newPhone);
    }
  }

  void _showOtpDialog(String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OtpVerificationDialog(
        phone: phone, 
        onVerified: () {
            Navigator.pop(context); // Close dialog
            _performUpdate(); // Proceed to update
        },
      ),
    );
  }

  Future<void> _performUpdate() async {
    setState(() => _isSaving = true);
    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;
    
    final apiService = ref.read(apiServiceProvider);
    
    try {
      String? uploadedPhotoUrl;
      if (_pickedImage != null) {
         uploadedPhotoUrl = await apiService.uploadFile(File(_pickedImage!.path));
         if (uploadedPhotoUrl == null) {
            throw Exception("Failed to upload image");
         }
      }

      final updatedUser = await apiService.updateProfile(
        currentUser.id,
        {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          if (uploadedPhotoUrl != null) 'profilePhoto': uploadedPhotoUrl,
        },
      );
      
      if (updatedUser != null) {
        await ref.read(userProvider.notifier).setUser(updatedUser);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } else {
        throw Exception("Failed to update profile");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    isDark = ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBGStart : AppTheme.lightBGStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GradientBackground(
        isDark: isDark,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                InkWell(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), width: 4),
                        ),
                        child: ClipOval(
                          child: _pickedImage != null
                            ? Image.file(
                                File(_pickedImage!.path),
                                fit: BoxFit.cover,
                              )
                            : UserAvatar(
                                photoUrl: ref.watch(userProvider)?.profilePhoto,
                                name: ref.watch(userProvider)?.name ?? "User",
                                radius: 60,
                              ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.camera, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Name Field
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: LucideIcons.user,
                ),
                const SizedBox(height: 20),
                
                // Phone Field
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: LucideIcons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 40),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _initiateSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.darkButton : AppTheme.lightButton,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.6)),
          prefixIcon: Icon(icon, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }
}

class _OtpVerificationDialog extends ConsumerStatefulWidget {
  final String phone;
  final VoidCallback onVerified;

  const _OtpVerificationDialog({required this.phone, required this.onVerified});

  @override
  ConsumerState<_OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends ConsumerState<_OtpVerificationDialog> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  String? _error;

  Future<void> _verify() async {
    if (_otpController.text.length != 6) {
      setState(() => _error = "Enter a valid 6-digit code");
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    final apiService = ref.read(apiServiceProvider);
    final result = await apiService.verifyOtp(widget.phone, _otpController.text);
    
    if (mounted) {
      setState(() => _isVerifying = false);
      if (result != null) {
        widget.onVerified();
      } else {
        setState(() => _error = "Invalid OTP. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.messageSquare,
                color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Verify Phone Number",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the code sent to ${widget.phone}",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLength: 6,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: "",
                  hintText: "000000",
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.darkButton : AppTheme.lightButton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isVerifying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Verify & Save", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))),
            ),
          ],
        ),
      ),
    );
  }
}
