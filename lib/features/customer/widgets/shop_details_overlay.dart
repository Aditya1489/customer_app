import 'package:flutter/material.dart';
import 'dart:io';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/widgets/universal_image.dart';

class ShopDetailsOverlay extends StatefulWidget {
  final BarberShop shop;
  final VoidCallback onClose;
  final Function(Staff staff) onStaffSelected;
  final VoidCallback onBookNow;
  final bool isDark;

  const ShopDetailsOverlay({
    super.key,
    required this.shop,
    required this.onClose,
    required this.onStaffSelected,
    required this.onBookNow,
    required this.isDark,
  });

  @override
  State<ShopDetailsOverlay> createState() => _ShopDetailsOverlayState();
}

class _ShopDetailsOverlayState extends State<ShopDetailsOverlay> {
  int _currentPhotoIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        isDark: widget.isDark,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
              child: _buildDetailsContent(context),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final photos = widget.shop.photos.isNotEmpty ? widget.shop.photos : [null];

    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.45,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.4),
          child: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
            onPressed: widget.onClose,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'shop-${widget.shop.id}',
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPhotoIndex = index),
                itemCount: photos.length,
                itemBuilder: (context, index) => UniversalImage(
                  imagePath: photos[index] as String?,
                  fit: BoxFit.cover,
                  placeholder: 'https://picsum.photos/800/600',
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0, 0.2, 0.7, 1],
                ),
              ),
            ),
            // Page Indicator
            if (photos.length > 1)
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    photos.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 4,
                      width: _currentPhotoIndex == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPhotoIndex == index ? AppTheme.darkAccent : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.shop.name,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: widget.isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.mapPin, size: 14, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.shop.address,
                            style: TextStyle(fontSize: 12, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.6)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.star, size: 16, color: Colors.yellow),
                      const SizedBox(width: 4),
                      Text(
                        widget.shop.rating.toString(),
                        style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                  Text(
                    "${widget.shop.reviewsCount} REVIEWS",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionHeader("Our Services"),
          const SizedBox(height: 16),
          ...widget.shop.services.map((service) => _buildServiceTile(service)),
          const SizedBox(height: 32),
          _buildSectionHeader("Our Barbers"),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: widget.shop.staff.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildStaffCard(widget.shop.staff[index]),
            ),
          ),
          const SizedBox(height: 120), // Bottom button space
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black),
    );
  }

  Widget _buildServiceTile(Service service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: UniversalImage(
                imagePath: service.imageUrl,
                fit: BoxFit.cover,
                placeholder: 'https://picsum.photos/200/200',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: widget.isDark ? Colors.white : Colors.black)),
                Text("${service.duration} min", style: TextStyle(fontSize: 12, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              ],
            ),
          ),
          Text(
            "\$${service.price}",
            style: const TextStyle(color: AppTheme.darkAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Staff staff) {
    return InkWell(
      onTap: () => widget.onStaffSelected(staff),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.1)),
              ),
              child: CircleAvatar(
                backgroundImage: (staff.imageUrl.startsWith('http'))
                      ? NetworkImage(staff.imageUrl) as ImageProvider
                      : FileImage(File(staff.imageUrl)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              staff.name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              staff.role,
              style: TextStyle(fontSize: 10, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        border: Border(top: BorderSide(color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.1))),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkButton,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 10,
          shadowColor: AppTheme.darkButton.withOpacity(0.4),
        ),
        onPressed: widget.onBookNow,
        child: const Text("Book Appointment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}
