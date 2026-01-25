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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleFinish() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);

    try {
      final registrationData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'password': _passwordController.text,
        'role': _selectedRole,
      };

      final response = await apiService.register(registrationData);
      
      if (response != null && response['user'] != null) {
        final userData = User.fromJson(response['user']);
        ref.read(userProvider.notifier).state = userData;

        if (mounted) {
          setState(() => _isLoading = false);
          context.go('/customer');
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registration failed. Please try again.")),
          );
        }
      }
    } catch (e) {
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
          const Text("Create Account", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          const Opacity(opacity: 0.4, child: Text("Join BarberSync to book your next grooming session.")),
          const SizedBox(height: 40),
          _buildInput("Full Name", "John Doe", _nameController, icon: LucideIcons.user),
          const SizedBox(height: 16),
          _buildInput("Email Address", "john@example.com", _emailController, icon: LucideIcons.mail, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildInput("Phone Number", "+1 234 567 890", _phoneController, icon: LucideIcons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _buildInput("Password", "••••••••", _passwordController, icon: LucideIcons.lock, isPassword: true),
          const SizedBox(height: 48),
          _buildPrimaryButton("SIGN UP & START", _handleFinish),
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
