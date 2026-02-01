import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:customer_sync/core/providers/user_provider.dart';

class SubmitReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bookingData;
  
  const SubmitReviewScreen({super.key, required this.bookingData});

  @override
  ConsumerState<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends ConsumerState<SubmitReviewScreen> {
  int _selectedRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = ref.read(userProvider);
    final api = ref.read(apiServiceProvider);
    
    final reviewData = {
      'shopId': widget.bookingData['shopId'],
      'staffId': widget.bookingData['staffId'],
      'customerId': user.id,
      'customerName': user.name,
      'rating': _selectedRating,
      'comment': _commentController.text.trim(),
    };

    final result = await api.submitReview(reviewData);

    if (mounted) {
      setState(() => _isSubmitting = false);
      
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your review!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit review. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffName = widget.bookingData['staffName'] ?? 'your barber';
    final shopName = widget.bookingData['shopName'] ?? 'the shop';
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Leave a Review'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Icon(
              LucideIcons.messageSquarePlus,
              size: 56,
              color: Colors.amber,
            ).animate().fadeIn().scale(begin: const Offset(0.5, 0.5)),
            
            const SizedBox(height: 16),
            
            Text(
              'How was your experience?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ).animate().fadeIn(delay: 100.ms),
            
            const SizedBox(height: 8),
            
            Text(
              'Rate $staffName at $shopName',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 150.ms),
            
            const SizedBox(height: 32),
            
            // Star Rating
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedRating > 0 
                      ? Colors.amber.withOpacity(0.5)
                      : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _getRatingText(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _selectedRating > 0 
                          ? Colors.amber 
                          : (isDark ? Colors.grey[500] : Colors.grey[400]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      final isSelected = starNum <= _selectedRating;
                      
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRating = starNum),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            isSelected ? LucideIcons.star : LucideIcons.star,
                            size: 40,
                            color: isSelected ? Colors.amber : Colors.grey[400],
                          ).animate(target: isSelected ? 1 : 0)
                            .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
                            .then()
                            .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 24),
            
            // Comment Field
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
              child: TextField(
                controller: _commentController,
                maxLines: 4,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ).animate().fadeIn(delay: 400.ms),
            
            const SizedBox(height: 16),
            
            // Skip Button
            TextButton(
              onPressed: () => context.pop(false),
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_selectedRating) {
      case 1:
        return 'Poor 😞';
      case 2:
        return 'Fair 😐';
      case 3:
        return 'Good 🙂';
      case 4:
        return 'Great 😊';
      case 5:
        return 'Excellent! 🤩';
      default:
        return 'Tap a star to rate';
    }
  }
}
