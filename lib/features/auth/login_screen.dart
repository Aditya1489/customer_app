import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:customer_sync/models/models.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  bool isLogin = true; // Still useful for UI text, though flow is same
  String? selectedRole = "CUSTOMER"; 
  late bool isDark;
  bool _isLoading = false;
  bool _isOtpSent = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  Future<void> _handlePhoneSubmit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name")),
      );
      return;
    }
    
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    
    // Request OTP
    final success = await apiService.requestOtp(phone);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        setState(() => _isOtpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send OTP. Please try again.")),
        );
      }
    }
  }

  Future<void> _handleOtpSubmit() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid 6-digit OTP")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    
    try {
      final response = await apiService.verifyOtp(_phoneController.text.trim(), otp);
      
      if (response != null) {
        if (response['access_token'] != null && response['action'] != 'REGISTER') {
           await _finalizeLogin(response);
        } else if (response['action'] == 'SELECT_ROLE') {
           // For Customer App, we should automatically pick 'CUSTOMER' role if available
           // or show error if not.
           final List roles = response['roles'] ?? [];
           final hasCustomerRole = roles.any((r) => r['role'] == 'CUSTOMER');
           
           if (hasCustomerRole) {
             // Select Customer Role
             final customerRole = roles.firstWhere((r) => r['role'] == 'CUSTOMER');
             final shopId = customerRole['shop_id'] ?? ""; // Usually null for generic customer
             final userId = response['user']['id'];
             
             final tokenResp = await apiService.selectRole(userId, "CUSTOMER", shopId);
             if (tokenResp != null) {
               await _finalizeLogin(tokenResp);
             } else {
               _showError("Failed to select role");
             }
           } else {
             _showError("This number is not registered as a customer.");
           }
        } else if (response['action'] == 'REGISTER') {
           print("DEBUG: Auto-registering new user...");
           
           final registerData = {
             'name': _nameController.text.trim(),
             'role': 'CUSTOMER',
             'email': null,
             'agreedToPrivacy': true,
             'agreedToTerms': true,
             'legalConsentName': _nameController.text.trim(),
             'legalConsentPlace': 'App Login',
             'legalConsentTimestamp': DateTime.now().toIso8601String(),
           };

           final regResponse = await apiService.registerUser(response['access_token'], registerData);
           
           if (regResponse != null) {
              print("DEBUG: Registration successful");
              final newUser = User.fromJson(regResponse['user']);
              final effectiveUser = newUser.copyWith(token: regResponse['access_token']);
              
              await ref.read(userProvider.notifier).setUser(effectiveUser);
              
              if (mounted) {
                // Determine shop ID (if any) to open specific shop page, else go home
                // For now, simple registration goes to home
                context.go('/customer');
              }
           } else {
             _showError("Registration failed. Please try again.");
           }
        }
      } else {
        _showError("Invalid OTP");
      }
    } catch (e) {
      _showError("Login error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _finalizeLogin(Map<String, dynamic> response) async {
    if (response['user'] != null) {
        var userData = User.fromJson(response['user']);
        
        // Attach token if available
        if (response['access_token'] != null) {
            userData = userData.copyWith(token: response['access_token']);
        }

        await ref.read(userProvider.notifier).setUser(userData);

        if (mounted) {
          context.go('/customer');
        }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    isDark = ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBGStart : AppTheme.lightBGStart,
      extendBody: true,
      body: GradientBackground(
        isDark: isDark,
        child: Stack(
          children: [
            // Theme Toggle
            Positioned(
              top: 0,
              right: 20,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    onTap: () => ref.read(themeProvider.notifier).state = !isDark,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDark ? LucideIcons.sun : LucideIcons.moon,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: selectedRole == null ? _buildRoleSelection() : _buildAuthForm(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 140),
          _buildLogo(),
          const SizedBox(height: 60),
            _buildRoleButton(
              "Continue as Customer",
              "Book appointments nearby",
              LucideIcons.user,
              AppTheme.darkAccent,
              () => setState(() => selectedRole = "CUSTOMER"),
            ),
            const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkButton,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: const Icon(LucideIcons.scissors, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 16),
        Text(
          "BarberSync",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 40,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          "Professional Grooming Marketplace",
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleButton(String title, String sub, IconData icon, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24), // Match React
      child: Container(
        padding: const EdgeInsets.all(20), // Standardized p-5
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(12), // rounded-lg
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(sub, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6))),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const SizedBox(height: 32),
          Text(
            _isOtpSent ? "Verify OTP" : "Welcome",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          SizedBox(
            height: 44, // Fixed height to prevent subtitle wrapping from jumping the layout
            child: Text(
              _isOtpSent 
                ? "Enter the code sent to ${_phoneController.text}" 
                : "Enter your phone number to continue",
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          if (!_isOtpSent) ...[
            _buildInput(LucideIcons.user, "Full Name", _nameController),
            const SizedBox(height: 16),
            _buildInput(LucideIcons.phone, "Phone Number", _phoneController),
          ],

          if (_isOtpSent)
             _buildInput(LucideIcons.key, "6-Digit OTP", _otpController),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading 
                  ? null 
                  : (_isOtpSent ? _handleOtpSubmit : _handlePhoneSubmit),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_isOtpSent ? "Login / Sign Up" : "Get OTP"),
            ),
          ),
          
          Visibility(
            visible: _isOtpSent,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _isOtpSent = false;
                  _otpController.clear();
                }),
                child: Text(
                  "Change Phone Number",
                  style: TextStyle(color: isDark ? AppTheme.darkAccent : Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInput(IconData icon, String hint, TextEditingController controller, {bool isPassword = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: hint.contains("Phone") || hint.contains("OTP") 
            ? TextInputType.number 
            : TextInputType.text,
        decoration: InputDecoration(
          icon: Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
          hintText: hint,
          border: InputBorder.none,
          hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
        ),
      ),
    );
  }
}
