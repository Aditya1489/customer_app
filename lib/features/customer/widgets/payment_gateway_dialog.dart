import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';

class PaymentGatewayDialog extends StatefulWidget {
  final double amount;
  final String currency;

  const PaymentGatewayDialog({
    super.key,
    required this.amount,
    this.currency = '₹',
  });

  @override
  State<PaymentGatewayDialog> createState() => _PaymentGatewayDialogState();
}

class _PaymentGatewayDialogState extends State<PaymentGatewayDialog> {
  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isError = false;

  Future<void> _processPayment(bool success) async {
    setState(() {
      _isProcessing = true;
      _isError = false;
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (success) {
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isProcessing = false;
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8F9FA),
                      isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Gateway',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(LucideIcons.x, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Amount to Pay: ',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${widget.currency}${widget.amount}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_isProcessing)
                _buildProcessingState()
              else if (_isSuccess)
                _buildSuccessState()
              else if (_isError)
                _buildErrorState()
              else
                _buildPaymentMethodsTable(),

              const SizedBox(height: 12),
              
              // Secure Badge
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Secure 256-bit encrypted payment',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
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

  Widget _buildProcessingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          const Text(
            'Verifying with Bank...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Please do not close this window',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.green, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            'Payment Successful!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 8),
          const Text('Your booking is being confirmed...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.alertCircle, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            'Payment Failed',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 8),
          const Text('Something went wrong with your bank.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _isError = false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Payment Method',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildMethodItem(LucideIcons.creditCard, 'Credit / Debit Card', 'Visa, Mastercard, RuPay', true),
          const SizedBox(height: 12),
          _buildMethodItem(LucideIcons.smartphone, 'UPI (Mock)', 'PhonePe, Google Pay, Paytm', true),
          const SizedBox(height: 12),
          _buildMethodItem(LucideIcons.building, 'Net Banking', 'All Indian Banks', false),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _processPayment(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    foregroundColor: Colors.grey.shade700,
                    elevation: 0,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Fail'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _processPayment(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: const Text('Pay ₹1 Now', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodItem(IconData icon, String title, String subtitle, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected 
          ? Colors.blue.withOpacity(0.05) 
          : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: isSelected ? Colors.blue : Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected ? Colors.blue : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(LucideIcons.checkCircle2, size: 18, color: Colors.blue),
        ],
      ),
    );
  }
}
