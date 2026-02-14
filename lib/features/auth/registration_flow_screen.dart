import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:customer_sync/models/models.dart';

class RegistrationFlowScreen extends ConsumerStatefulWidget {
  const RegistrationFlowScreen({super.key});

  @override
  ConsumerState<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends ConsumerState<RegistrationFlowScreen> {
  String _step = 'customer_details';
  final String _selectedRole = 'CUSTOMER';
  bool _isLoading = false;
  late bool isDark;

  // Customer states
  // Customer states
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(userProvider);
    _nameController = TextEditingController(text: currentUser?.name ?? "");
  }

  Future<void> _handleFinish() async {
    print("DEBUG: _handleFinish called");
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your name.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    final currentUser = ref.read(userProvider);
    
    if (currentUser == null) {
       print("DEBUG: currentUser is null");
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User session not found. Please login again.")),
      );
       setState(() => _isLoading = false);
       return;
    }

    print("DEBUG: Current User ID: ${currentUser.id}");

    try {
      User? effectiveUser;
      
      if (currentUser.id == 'temp') {
        // 1. New Registration
        print("DEBUG: Starting new registration");
        final registerData = {
          'name': _nameController.text.trim(),
          'role': 'CUSTOMER',
          'email': null,
          'agreedToPrivacy': true, // Simple consent for customer
          'agreedToTerms': true,
          'legalConsentName': _nameController.text.trim(),
          'legalConsentPlace': 'App Registration',
          'legalConsentTimestamp': DateTime.now().toIso8601String(),
        };
        print("DEBUG: Register Payload: $registerData");
        
        final regResponse = await apiService.registerUser(currentUser.token!, registerData);
        print("DEBUG: Register Response: $regResponse");

        if (regResponse == null) throw Exception("Registration failed (response was null).");
        
        final newUser = User.fromJson(regResponse['user']);
        effectiveUser = newUser.copyWith(token: regResponse['access_token']);
      } else {
        // 2. Existing User Update
        print("DEBUG: Updating existing user profile");
        final profileData = {'name': _nameController.text.trim()};
        effectiveUser = await apiService.updateProfile(currentUser.id, profileData);
        print("DEBUG: Update Profile Result: ${effectiveUser != null ? 'Success' : 'Fail'}");
      }
      
      if (effectiveUser != null) {
        print("DEBUG: Successfully set user");
        await ref.read(userProvider.notifier).setUser(effectiveUser);

        if (mounted) {
          setState(() => _isLoading = false);
          context.go('/customer');
        }
      } else {
        print("DEBUG: effectiveUser is null");
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile update failed. Please try again.")),
          );
        }
      }
    } catch (e, stack) {
      print("DEBUG: Error in _handleFinish: $e");
      print(stack);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    isDark = ref.watch(themeProvider);
    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        isDark: isDark,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildCustomerDetailsStep(),
        ),
      ),
    );
  }

  Widget _buildCustomerDetailsStep() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          _buildBackButton(() => context.pop()),
          const SizedBox(height: 24),
          const Text("Complete Profile", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          const Opacity(opacity: 0.4, child: Text("Tell us a bit about yourself to get started.")),
          const SizedBox(height: 40),
          _buildInput("Full Name", "John Doe", _nameController, icon: LucideIcons.user),
          const SizedBox(height: 48),
          _buildPrimaryButton("COMPLETE SETUP", _handleFinish),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBackButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.arrowLeft, size: 20),
      ),
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController controller, 
      {IconData? icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              icon: icon != null ? Icon(icon, size: 18, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3)) : null,
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), fontWeight: FontWeight.normal),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkButton,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : onTap,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
