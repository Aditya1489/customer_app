import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/widgets/universal_image.dart';
import 'package:customer_sync/widgets/user_avatar.dart';

class StaffProfileOverlay extends StatelessWidget {
  final Staff staff;
  final VoidCallback onClose;
  final bool isDark;

  const StaffProfileOverlay({
    super.key,
    required this.staff,
    required this.onClose,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        isDark: isDark,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.4),
                  child: IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
                    onPressed: onClose,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    UserAvatar(
                      radius: 64,
                      photoUrl: staff.imageUrl,
                      name: staff.name,
                      fontSize: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(staff.name, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                    Text(
                      staff.role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppTheme.darkAccent,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildStatsRow(),
                    const SizedBox(height: 48),
                    _buildAboutSection(),
                    const SizedBox(height: 48),
                    _buildPortfolioSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(staff.experience.toString() + "y", "EXP."),
        Container(width: 1, height: 24, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
        _buildStatItem(staff.rating.toString(), "RATING"),
        Container(width: 1, height: 24, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
        _buildStatItem(staff.reviewsCount.toString(), "REVIEWS"),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 12),
        Text(
          staff.description,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Portfolio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: staff.workPhotos.length,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: UniversalImage(
                imagePath: staff.workPhotos[index],
                fit: BoxFit.cover,
                placeholder: 'https://picsum.photos/400/400',
              ),
            );
          },
        ),
      ],
    );
  }
}
