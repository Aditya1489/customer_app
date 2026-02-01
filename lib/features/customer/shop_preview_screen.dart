import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:customer_sync/widgets/user_avatar.dart';
import 'package:customer_sync/widgets/universal_image.dart';
import 'package:customer_sync/models/models.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ShopPreviewScreen extends ConsumerStatefulWidget {
  final BarberShop shop;

  const ShopPreviewScreen({super.key, required this.shop});

  @override
  ConsumerState<ShopPreviewScreen> createState() => _ShopPreviewScreenState();
}

class _ShopPreviewScreenState extends ConsumerState<ShopPreviewScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageController _photoPageController = PageController();
  int _currentPhotoIndex = 0;
  String _activeSection = "About";

  @override
  void dispose() {
    _scrollController.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final photos = widget.shop.photos;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(isDark, photos),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildNavigationChips(isDark),
                    _buildShopContent(isDark),
                  ],
                ),
              ),
            ],
          ),
          _buildStickyBookNow(isDark),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, List<String> photos) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      elevation: 0,
      stretch: true,
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
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            photos.isNotEmpty 
                ? _buildPhotoGallery(photos)
                : const UniversalImage(
                    imagePath: "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?auto=format&fit=crop&q=80&w=800",
                    fit: BoxFit.cover,
                  ),
            // Dark Gradient Overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    (isDark ? const Color(0xFF0C0C0E) : Colors.black).withOpacity(0.8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4],
                ),
              ),
            ),
            // Identity Line & Badges Overlay
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("OPEN NOW", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("~15 MIN WAIT", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                  const SizedBox(height: 12),
                  Text(
                    widget.shop.name,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                  const SizedBox(height: 4),
                  const Text(
                    "Modern Cuts · Clean Fades · Men's Grooming",
                    style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationChips(bool isDark) {
    final sections = ["About", "Team", "Services", "Reviews"];
    return Container(
      color: isDark ? const Color(0xFF0C0C0E) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: sections.map((s) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(s),
              selected: _activeSection == s,
              onSelected: (val) { if(val) setState(() => _activeSection = s); },
              backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              selectedColor: AppTheme.emerald,
              labelStyle: TextStyle(
                color: _activeSection == s ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.bold,
                fontSize: 12
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildShopContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. About Section
          const SizedBox(height: 8),
          _sectionTitle("The Experience"),
          const SizedBox(height: 12),
          Text(
            widget.shop.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.7), 
              fontSize: 14, 
              height: 1.6,
              fontWeight: FontWeight.w500
            ),
          ),
          const SizedBox(height: 32),

          // 2. Meet the Team
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle("Meet the Team"),
              Text("${widget.shop.staff.length} Masters", style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildStaffGrid(isDark),
          const SizedBox(height: 32),

          // 3. Trust & Social Proof
          _buildTrustBanner(isDark),
          const SizedBox(height: 32),

          // 4. Services
          _sectionTitle("Our Services"),
          const SizedBox(height: 16),
          _buildServicesGrouped(isDark),
          const SizedBox(height: 120), // Bottom padding for CTA
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey),
    );
  }

  Widget _buildStaffGrid(bool isDark) {
    final staff = widget.shop.staff;
    if (staff.isEmpty) return const Text("No staff added yet.");

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: staff.length,
        itemBuilder: (context, index) {
          final member = staff[index];
          bool isOwner = member.role.toLowerCase().contains('owner');

          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => context.push('/staff-preview', extra: {'staff': member, 'shop': widget.shop}),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Hero(
                        tag: 'staff-${member.id}',
                        child: UserAvatar(
                          radius: 38,
                          photoUrl: member.imageUrl,
                          name: member.name,
                        ),
                      ),
                      if (isOwner)
                        Positioned(
                          top: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.crown, color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    member.name.split(' ').first,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                  ),
                  Text(
                    isOwner ? "Owner" : member.role,
                    style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).scale(begin: const Offset(0.9, 0.9));
        },
      ),
    );
  }

  Widget _buildTrustBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.emerald.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _trustIcon(LucideIcons.heart, "Loved by 200+ clients"),
          _trustIcon(LucideIcons.shieldCheck, "Clean & Hygienic"),
          _trustIcon(LucideIcons.medal, "Certified Masters"),
        ],
      ),
    );
  }

  Widget _trustIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.emerald),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildServicesGrouped(bool isDark) {
    final services = widget.shop.services;
    if (services.isEmpty) return const Text("No services available.");

    return Column(
      children: [
        _serviceCategory(isDark, "Popular Picks", services.take(2).toList(), isHot: true),
        const SizedBox(height: 24),
        _serviceCategory(isDark, "Main Menu", services.skip(2).toList()),
      ],
    );
  }

  Widget _serviceCategory(bool isDark, String title, List<Service> items, {bool isHot = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (isHot) ...[
              const SizedBox(width: 8),
              const Icon(LucideIcons.flame, color: Colors.orange, size: 14),
            ]
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((s) => _serviceCard(isDark, s, isHot)),
      ],
    );
  }

  Widget _serviceCard(bool isDark, Service service, bool highlight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (highlight) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text("TOP", style: TextStyle(color: AppTheme.emerald, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Professional ${service.name.toLowerCase()} with custom styling.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text("${service.duration} mins", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "\$${service.price}",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.emerald),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildStickyBookNow(bool isDark) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0C0C0E) : Colors.white).withOpacity(0.95),
          border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                final result = await context.push('/booking', extra: {'shop': widget.shop});
                if (result == true && mounted) context.pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                "BOOK APPOINTMENT",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(List<String> photos) {
     return Stack(
       children: [
         PageView.builder(
           controller: _photoPageController,
           itemCount: photos.length,
           onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
           itemBuilder: (context, index) {
             return UniversalImage(
               imagePath: photos[index],
               fit: BoxFit.cover,
               placeholder: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?auto=format&fit=crop&q=80&w=800',
             );
           },
         ),
         if (photos.length > 1)
           Positioned(
             bottom: 110, // Above the content overlay
             left: 0, right: 0,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: List.generate(photos.length, (index) => AnimatedContainer(
                 duration: const Duration(milliseconds: 300),
                 margin: const EdgeInsets.symmetric(horizontal: 4),
                 height: 6,
                 width: _currentPhotoIndex == index ? 20 : 6,
                 decoration: BoxDecoration(
                   color: _currentPhotoIndex == index ? AppTheme.emerald : Colors.white.withOpacity(0.5),
                   borderRadius: BorderRadius.circular(3),
                 ),
               )),
             ),
           ),
       ],
     );
  }
}
