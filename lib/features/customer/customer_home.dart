import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/services/mock_data.dart';
import 'package:customer_sync/features/customer/widgets/shop_details_overlay.dart';
import 'package:customer_sync/features/customer/widgets/staff_profile_overlay.dart';
import 'package:customer_sync/features/customer/widgets/booking_flow_overlay.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:customer_sync/widgets/user_avatar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:customer_sync/widgets/universal_image.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  List<BarberShop> _shops = [];
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  String _activeAppointmentFilter = 'PENDING';
  bool _viewingMap = false;
  int _currentIndex = 0;
  BarberShop? _selectedShop;
  String? _bookingStep; // 'staff', 'services', 'slot', 'summary'
  Staff? _selectedStaff;
  Staff? _viewingStaff;
  late bool isDark;
  Position? _currentPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadData();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
      // Filter nearby shops if needed, or just center the map
      if (_viewingMap) {
        _mapController.move(LatLng(position.latitude, position.longitude), 14);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = ref.read(userProvider);
    final apiService = ref.read(apiServiceProvider);
    
    try {
      final results = await Future.wait([
        apiService.getShops(),
        apiService.getAppointments(user.id),
      ]);
      
      if (mounted) {
        setState(() {
          _shops = results[0] as List<BarberShop>;
          _appointments = results[1] as List<Appointment>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    isDark = ref.watch(themeProvider);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: _buildTabContent(),
          bottomNavigationBar: _buildBottomNav(),
        ),
        if (_selectedShop != null && _bookingStep == null)
          Positioned.fill(
            child: ShopDetailsOverlay(
              shop: _selectedShop!,
              isDark: isDark,
              onClose: () => setState(() => _selectedShop = null),
              onStaffSelected: (staff) {
                setState(() => _viewingStaff = staff);
              },
              onBookNow: () => setState(() => _bookingStep = 'staff'),
            ),
          ),
        if (_bookingStep != null)
          Positioned.fill(
            child: BookingFlowOverlay(
              shop: _selectedShop!,
              initialStaff: _selectedStaff,
              isDark: isDark,
              onClose: () => setState(() {
                _bookingStep = null;
                _selectedStaff = null;
              }),
              onComplete: (appt) {
                setState(() {
                  _appointments.insert(0, appt);
                  _bookingStep = null;
                  _selectedShop = null;
                  _selectedStaff = null;
                  _currentIndex = 1; // Go to Bookings tab
                });
              },
            ),
          ),
        if (_viewingStaff != null)
          Positioned.fill(
            child: StaffProfileOverlay(
              staff: _viewingStaff!,
              isDark: isDark,
              onClose: () => setState(() => _viewingStaff = null),
            ),
          ),
      ],
    );
  }

  Widget _buildTabContent() {
    return GradientBackground(
      isDark: isDark,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildExploreTab();
      case 2:
        return _buildAppointmentsTab();
      case 3:
        return _buildProfileTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildExploreTab() {
    // Aggregate all photos from shops and staff
    final List<Map<String, dynamic>> allItems = [];
    
    for (var shop in _shops) {
      // Add shop photos
      for (var photo in shop.photos) {
        allItems.add({
          'type': 'shop',
          'photo': photo,
          'title': shop.name,
          'subtitle': 'Salon Gallery',
          'shop': shop,
        });
      }
      
      // Add staff photos
      for (var staff in shop.staff) {
        for (var photo in staff.workPhotos) {
          allItems.add({
            'type': 'staff',
            'photo': photo,
            'title': staff.name,
            'subtitle': '${shop.name} • Portfolio',
            'shop': shop,
            'staff': staff,
          });
        }
      }
    }

    // Shuffle for freshness
    allItems.shuffle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Explore Gallery",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
              ),
              Text(
                "Real work by local barbers",
                style: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
              ),
            ],
          ),
        ),
        Expanded(
          child: allItems.isEmpty
              ? Center(child: Text("No photos uploaded yet", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: allItems.length,
                  itemBuilder: (context, index) => _buildExploreCard(allItems[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildExploreCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? (Colors.white.withOpacity(0.05)) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedShop = item['shop']),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    UniversalImage(
                      imagePath: item['photo'],
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['title'],
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    item['subtitle'],
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.darkAccent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(LucideIcons.scissors, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Find Your Style",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                      ),
                      Text(
                        "Near 123 Main St, New York",
                        style: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBG : Colors.white,
                      shape: BoxShape.circle,
                      border: isDark ? null : Border.all(color: Colors.black.withOpacity(0.1)),
                    ),
                    child: Icon(LucideIcons.bell, size: 20, color: isDark ? Colors.white : Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardBG : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          icon: Icon(LucideIcons.search, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                          hintText: "Search barber shops...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => setState(() => _viewingMap = !_viewingMap),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _viewingMap ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) : (isDark ? AppTheme.darkCardBG : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: isDark ? null : (_viewingMap ? null : Border.all(color: Colors.black.withOpacity(0.1))),
                      ),
                      child: Icon(LucideIcons.map, size: 20, color: _viewingMap ? Colors.white : (isDark ? Colors.white : Colors.black)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("Nearby", true),
                const SizedBox(width: 8),
                _buildFilterChip("Popular", false),
                const SizedBox(width: 8),
                _buildFilterChip("Top Rated", false),
                const SizedBox(width: 8),
                _buildFilterChip("Price", false),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _viewingMap
              ? _buildMapView()
              : _shops.isEmpty
                ? Center(child: Text("No shops found near you", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _shops.length,
                      itemBuilder: (context, index) => _buildShopCard(_shops[index]),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildShopCard(BarberShop shop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: UniversalImage(
                  imagePath: shop.photos.isNotEmpty ? shop.photos[0] : null,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.star, color: Colors.yellow, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        shop.rating.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  shop.address,
                  style: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildShopAction(LucideIcons.navigation, "NAVIGATE", isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFE8F0FE), Colors.blue, () async {
                      final apiService = ref.read(apiServiceProvider);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fetching location and route...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }

                      // Request permission
                      LocationPermission permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                      }

                      double? userLat;
                      double? userLng;
                      try {
                        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                          // Get current location with timeout
                          final position = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high,
                            timeLimit: const Duration(seconds: 5),
                          );
                          userLat = position.latitude;
                          userLng = position.longitude;
                        }
                      } catch (e) {
                        print('Location error: $e');
                      }

                      // Get pre-formatted Google Maps URL from backend
                      final googleMapsUrl = await apiService.getNavigationLink(
                        shop.id,
                        lat: userLat,
                        lng: userLng,
                      );

                      if (googleMapsUrl != null) {
                        final uri = Uri.parse(googleMapsUrl);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open maps application')),
                            );
                          }
                        }
                      }
                    }),
                    const SizedBox(width: 8),
                    _buildShopAction(LucideIcons.sliders, "DETAILS", (isDark ? Colors.white : Colors.black).withOpacity(0.05), isDark ? Colors.white : Colors.black, () {
                      setState(() => _selectedShop = shop);
                    }),
                    const SizedBox(width: 8),
                    _buildShopAction(LucideIcons.calendar, "BOOK NOW", isDark ? AppTheme.darkAccent : AppTheme.lightAccent, Colors.white, () {
                      setState(() {
                        _selectedShop = shop;
                        _bookingStep = 'staff';
                      });
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopAction(IconData icon, String label, Color bgColor, Color iconColor, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: iconColor, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    final LatLng center = _currentPosition != null 
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(40.7128, -74.0060); // Default to NYC if unknown

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.barbersync.barber_sync',
            ),
            MarkerLayer(
              markers: [
                if (_currentPosition != null)
                  Marker(
                    point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.location_history, color: Colors.blue, size: 20),
                      ),
                    ),
                  ),
                ..._shops.map((shop) => Marker(
                  point: LatLng(
                    shop.coordinates['lat'] ?? 0, 
                    shop.coordinates['lng'] ?? 0
                  ),
                  width: 50,
                  height: 50,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedShop = shop),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkButton,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(LucideIcons.scissors, color: Colors.white, size: 18),
                    ),
                  ),
                )).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    final categories = [
      {'id': 'PENDING', 'label': 'Pending'},
      {'id': 'ACCEPTED', 'label': 'Accepted'},
      {'id': 'COMPLETED', 'label': 'Completed'},
      {'id': 'CANCELLED', 'label': 'Cancelled'}
    ];

    final filtered = _appointments.where((a) => a.status.toString().split('.').last.toUpperCase() == _activeAppointmentFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Appointments",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: categories.map((cat) {
                    bool isSelected = _activeAppointmentFilter == cat['id'];
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeAppointmentFilter = cat['id']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? (isDark ? AppTheme.darkCardBG : Colors.white) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isSelected && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Opacity(
                    opacity: 0.4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.calendar, size: 64, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                        const SizedBox(height: 16),
                        Text("No appointments found", style: TextStyle(fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final appt = filtered[index];
                      final shop = _shops.firstWhere((s) {
                        try {
                          return s.id == appt.shopId;
                        } catch (e) {
                          return false;
                        }
                      }, orElse: () => _shops.isNotEmpty ? _shops[0] : mockShops[0]);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCardBG : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(image: NetworkImage(shop.photos[0]), fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(shop.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                                  Text("${appt.date} • ${appt.timeSlot}", style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6))),
                                  const SizedBox(height: 4),
                                  Text(
                                    "\$${appt.totalAmount}",
                                    style: TextStyle(color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Icon(LucideIcons.chevronRight, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }



  Widget _buildProfileTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
              InkWell(
                onTap: () => ref.read(themeProvider.notifier).state = !isDark,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBG : Colors.white,
                    shape: BoxShape.circle,
                    border: isDark ? null : Border.all(color: AppTheme.lightAccent, width: 2),
                  ),
                  child: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, size: 20, color: isDark ? Colors.white : AppTheme.lightAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Profile Card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBG : Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      UserAvatar(
                        user: ref.watch(userProvider),
                        radius: 50,
                        isDark: isDark,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.amber : AppTheme.lightAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.camera, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(ref.watch(userProvider).name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 4),
                  Opacity(opacity: 0.6, child: Text(ref.watch(userProvider).phone, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildProfileItem(LucideIcons.user, "Edit Profile", isDark ? Colors.amber : AppTheme.lightAccent, () {
            context.push('/edit-profile');
          }),
          const SizedBox(height: 16),
          _buildProfileItem(LucideIcons.shield, "Manage Permissions", isDark ? Colors.amber : AppTheme.lightAccent, () {
            context.push('/manage-permissions');
          }),
          const SizedBox(height: 40),
          // Logout Button
          InkWell(
            onTap: () => context.go('/login'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.logOut, color: Colors.red, size: 24),
                  SizedBox(width: 16),
                  Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 17)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? (Colors.white.withOpacity(0.08)) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 20),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black))),
            Icon(LucideIcons.chevronRight, size: 18, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected 
            ? (isDark ? AppTheme.darkCardBG : Colors.white)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: isDark 
            ? null 
            : Border.all(color: isSelected ? Colors.transparent : Colors.black.withOpacity(0.1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected 
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white : Colors.black).withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.95),
        border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(0, LucideIcons.home, "HOME"),
              _buildNavItem(1, LucideIcons.camera, "EXPLORE"),
              _buildNavItem(2, LucideIcons.calendar, "BOOKINGS"),
              _buildNavItem(3, LucideIcons.user, "PROFILE"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isActive = _currentIndex == index;
    Color color = isActive ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) : (isDark ? Colors.white : Colors.black).withOpacity(0.4);

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
