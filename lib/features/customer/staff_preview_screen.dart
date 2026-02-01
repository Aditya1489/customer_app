import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/widgets/user_avatar.dart';
import 'package:customer_sync/widgets/universal_image.dart';
import 'package:customer_sync/models/models.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaffPreviewScreen extends ConsumerStatefulWidget {
  final Staff staff;
  final BarberShop? shop;

  const StaffPreviewScreen({super.key, required this.staff, this.shop});

  @override
  ConsumerState<StaffPreviewScreen> createState() => _StaffPreviewScreenState();
}

class _StaffPreviewScreenState extends ConsumerState<StaffPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final badgeInfo = _getExperienceBadgeInfo(widget.staff.experience);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          // 1. Premium Hero Header
          _buildHeroHeader(isDark, badgeInfo),

          // 2. Stats Section
          SliverToBoxAdapter(child: _buildStats(isDark)),

          // 3. Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Me
                  _sectionHeader("The Story"),
                  const SizedBox(height: 12),
                  Text(
                    widget.staff.description.isNotEmpty 
                      ? widget.staff.description 
                      : "A dedicated professional committed to delivering the highest quality service and ensuring every client leaves looking and feeling their best.",
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 40),

                  // Portfolio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader("Masterpieces"),
                      Text("${widget.staff.workPhotos.length} Photos", style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPortfolioGrid(),

                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionCTA(isDark),
    );
  }

  Widget _buildHeroHeader(bool isDark, Map<String, dynamic>? badgeInfo) {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : Colors.white,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.3),
          child: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Hero Background Movie Poster Style (No Hero tag here)
            UniversalImage(
              imagePath: widget.staff.imageUrl,
              fit: BoxFit.cover,
              placeholder: 'https://images.unsplash.com/photo-1599305090598-fe175782860a?auto=format&fit=crop&q=80&w=800',
            ),
            
            // 2. Backdrop Blur and Gradient
            ClipRRect(
              child: BackdropFilter(
                filter: ColorFilter.mode(
                  Colors.black.withOpacity(isDark ? 0.3 : 0.4),
                  BlendMode.darken,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            
            // Gradient Overlays for readability
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.transparent,
                    (isDark ? const Color(0xFF0C0C0E) : Colors.black).withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),

            // 3. Centered Profile Content
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  Hero(
                    tag: 'staff-${widget.staff.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                        ],
                      ),
                      child: UserAvatar(
                        radius: 54,
                        photoUrl: widget.staff.imageUrl,
                        name: widget.staff.name,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.staff.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                  ).animate().fadeIn().slideY(begin: 0.2),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.staff.role.toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald, letterSpacing: 2),
                      ),
                      const SizedBox(width: 12),
                      if (badgeInfo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (badgeInfo['color'] as Color).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: (badgeInfo['color'] as Color).withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.award, size: 10, color: badgeInfo['color'] as Color),
                              const SizedBox(width: 4),
                              Text(
                                badgeInfo['label'].toString().toUpperCase(),
                                style: TextStyle(color: badgeInfo['color'] as Color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                isDark,
                "${widget.staff.experience}",
                "Years",
                LucideIcons.briefcase,
                Colors.blue,
              ),
            ),
            _verticalDivider(isDark),
            Expanded(
              child: _buildStatItem(
                isDark,
                widget.staff.rating.toStringAsFixed(1),
                "Rating",
                LucideIcons.star,
                widget.staff.rating > 0 ? Colors.amber : Colors.grey,
              ),
            ),
            _verticalDivider(isDark),
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/staff-reviews', extra: widget.staff.id),
                child: _buildStatItem(
                  isDark,
                  "${widget.staff.reviewsCount}",
                  "Reviews",
                  LucideIcons.messageSquare,
                  widget.staff.reviewsCount > 0 ? Colors.purple : Colors.grey,
                  showArrow: true,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildStatItem(bool isDark, String value, String label, IconData icon, Color color, {bool showArrow = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
            if (showArrow) ...[
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronRight, size: 12, color: color.withOpacity(0.5)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(width: 1, height: 40, color: (isDark ? Colors.white : Colors.black).withOpacity(0.06));
  }

  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey),
    );
  }

  Widget _buildPortfolioGrid() {
    final photos = widget.staff.workPhotos;
    if (photos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: const Column(
          children: [
            Icon(LucideIcons.camera, color: Colors.grey, size: 32),
            SizedBox(height: 12),
            Text("No work photos yet", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: UniversalImage(
              imagePath: photos[index],
              fit: BoxFit.cover,
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).scale(begin: const Offset(0.9, 0.9));
      },
    );
  }

  Widget _buildActionCTA(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0C0E) : Colors.white,
        border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () async {
              final result = await context.push('/booking', extra: {
                'shop': widget.shop ?? (widget.staff.shopId != null ? BarberShop(id: widget.staff.shopId!, name: '', address: '', description: '', rating: 0, reviewsCount: 0, photos: [], coordinates: {}, staff: [], services: []) : null),
                'staff': widget.staff
              });
              if (result == true && mounted) context.pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text("BOOK THIS BARBER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _getExperienceBadgeInfo(int experience) {
    if (experience >= 10) {
      return {'label': 'Master Barber', 'color': Colors.purple};
    } else if (experience >= 5) {
      return {'label': 'Experienced Pro', 'color': Colors.blue};
    } else if (experience >= 2) {
      return {'label': 'Skilled Stylist', 'color': Colors.teal};
    }
    return null;
  }
}
