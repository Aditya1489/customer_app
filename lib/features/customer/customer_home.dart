import 'dart:async';
import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/core/config/app_config.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/services/mock_data.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:customer_sync/widgets/user_avatar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:customer_sync/widgets/universal_image.dart';
import 'package:customer_sync/services/notification_service.dart';
import 'package:customer_sync/services/map_services.dart' as services; // Alias due to conflict? Or just use directly.
import 'package:intl/intl.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:customer_sync/features/customer/navigation_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  late Razorpay _razorpay;
  String? _currentBookingId;
  final PageController _pageController = PageController();
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
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Nearby';
  final services.MapServices _mapServices = services.MapServices('AIzaSyCzmacRHEb3q8kLOWG5ZA9L4qM_fUUJvKc');
  
  List<BarberShop> get _filteredShops {
    List<BarberShop> shops = List.from(_shops);
    
    // 1. Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      shops = shops.where((shop) => 
        shop.name.toLowerCase().contains(query) || 
        shop.address.toLowerCase().contains(query)
      ).toList();
    }

    // 2. Apply Sorting based on Filter
    switch (_selectedFilter) {
      case 'Nearby':
        if (_currentPosition != null) {
          shops.sort((a, b) {
            final distA = Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude, 
              a.coordinates['lat'] ?? 0, a.coordinates['lng'] ?? 0
            );
            final distB = Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude, 
              b.coordinates['lat'] ?? 0, b.coordinates['lng'] ?? 0
            );
            return distA.compareTo(distB);
          });
        }
        break;
      case 'Popular':
        shops.sort((a, b) => b.reviewsCount.compareTo(a.reviewsCount));
        break;
      case 'Top Rated':
        shops.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Price':
      case 'Price: Low to High':
        shops.sort((a, b) {
          double avgPriceA = a.services.isEmpty ? 0 : a.services.map((s) => s.price).reduce((a, b) => a + b) / a.services.length;
          double avgPriceB = b.services.isEmpty ? 0 : b.services.map((s) => s.price).reduce((a, b) => a + b) / b.services.length;
          return avgPriceA.compareTo(avgPriceB);
        });
        break;
      case 'Price: High to Low':
        shops.sort((a, b) {
          double avgPriceA = a.services.isEmpty ? 0 : a.services.map((s) => s.price).reduce((a, b) => a + b) / a.services.length;
          double avgPriceB = b.services.isEmpty ? 0 : b.services.map((s) => s.price).reduce((a, b) => a + b) / b.services.length;
          return avgPriceB.compareTo(avgPriceA);
        });
        break;
    }
    
    return shops;
  }

  // Advanced Map State
  Set<Polyline> _polylines = {};
  MapType _currentMapType = MapType.normal;
  bool _trafficEnabled = false;
  List<services.PlacePrediction> _placePredictions = [];
  bool _showPredictions = false;
  bool _isNavigating = false;
  BarberShop? _navigationShop;
  String _navigationDistance = '0.0 km';
  String _navigationDuration = '0 min';
  String _navigationArrivalTime = '--:--';
  
  Set<Marker> _customMarkers = {};
  BarberShop? _selectedMapShop;
  Offset? _popupPosition;
  final LayerLink _layerLink = LayerLink();

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _checkLocationPermission();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProvider);
      if (user != null) {
        ref.read(notificationServiceProvider).startPolling(user!.id);
      }
    });

    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _currentIndex == 1 && _activeAppointmentFilter == 'AWAITING_CUSTOMER_CONFIRMATION') {
        setState(() {}); // Rebuild to update countdowns
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    ref.read(notificationServiceProvider).stopPolling();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_currentBookingId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post('/bookings/$_currentBookingId/confirm-payment', {
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'razorpay_signature': response.signature,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Appointment Confirmed. ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _currentBookingId = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Failed: ${response.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    _currentBookingId = null;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External Wallet Selected: ${response.walletName}')),
      );
    }
  }

  void _startRazorpayCheckout(Map<String, dynamic> orderData, String bookingId) {
    _currentBookingId = bookingId;
    
    var options = {
      'key': orderData['key'],
      'amount': orderData['amount'],
      'name': 'BarberSync',
      'description': 'Booking Confirmation Fee',
      'order_id': orderData['id'],
      'timeout': 300, 
      'prefill': {
        'contact': ref.read(userProvider)?.phone ?? '',
        'email': ref.read(userProvider)?.email ?? '',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
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
      if (_viewingMap && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 14));
      }
    }
  }

  Future<void> _loadData({User? currentUser}) async {
    final user = currentUser ?? ref.read(userProvider);
    if (user == null) {
      print('⚠️ [BOOKING] Cannot load data: user is null (waiting for auth restoration...)');
      return;
    }
    
    print('✅ [BOOKING] Loading data for user: ${user.id}');
    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    
    try {
      print('📡 [BOOKING] Fetching appointments for customer_id: ${user.id}');
      final results = await Future.wait([
        apiService.getShops(),
        apiService.getAppointments(user.id),
      ]);
      
      final appointments = results[1] as List<Appointment>;
      print('✅ [BOOKING] Received ${appointments.length} appointments');
      
      if (mounted) {
        setState(() {
          _shops = results[0] as List<BarberShop>;
          _appointments = appointments;
          _isLoading = false;
        });
        _generateMarkers();
      }
    } catch (e) {
      print('❌ [BOOKING] Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index, 
      duration: const Duration(milliseconds: 300), 
      curve: Curves.easeInOut
    );
    setState(() => _currentIndex = index);
    if (index == 1) {
      // Mark all notifications as read when entering bookings tab
      _markNotificationsAsRead();
    }
  }

  void _handleBookingSuccess() {
    _loadData();
    _onTabTapped(1); 
    setState(() => _activeAppointmentFilter = 'PENDING');
  }

  Future<void> _markNotificationsAsRead() async {
    final user = ref.read(userProvider);
    if (user == null) return;
    
    final apiService = ref.read(apiServiceProvider);
    final notifications = await apiService.getNotifications(user!.id);
    
    for (var notif in notifications) {
      if (!notif['isRead']) {
        await apiService.markNotificationAsRead(notif['id']);
      }
    }
    // Update local count
    ref.read(unreadNotificationCountProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    isDark = ref.watch(themeProvider);
    final user = ref.watch(userProvider);

    // Listen for User Auth Restoration
    ref.listen<User?>(userProvider, (previous, next) {
      if (previous == null && next != null) {
        print("🔐 [HOME] User restored! Triggering data load for ${next.id}");
        _loadData(currentUser: next);
      }
    });

    // Auto-refresh when notification service triggers (e.g. status change)
    ref.listen(refreshTriggerProvider, (prev, next) {
      if (next > (prev ?? 0)) {
        _loadData();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBGStart : AppTheme.lightBGStart,
      extendBody: true,
      body: GradientBackground(
        isDark: isDark,
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) _markNotificationsAsRead();
      },
      children: [
        _buildHomeTab(),
        _buildAppointmentsTab(),
        _buildProfileTab(),
      ],
    );
  }

  Widget _buildHomeTab() {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _showPredictions = false;
              FocusScope.of(context).unfocus();
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (!_isNavigating)
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
                              _currentPosition != null ? "Nearby • Using your location" : "Enable location for nearby shops",
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
                        child: CompositedTransformTarget(
                          link: _layerLink,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCardBG : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                        if (value.isNotEmpty && _viewingMap) {
                                          _fetchPredictions(value);
                                        } else {
                                          _placePredictions = [];
                                          _showPredictions = false;
                                        }
                                        _generateMarkers(); // Regenerate markers for filtered list
                                      });
                                    },
                                    decoration: InputDecoration(
                                      icon: Icon(LucideIcons.search, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                                      hintText: "Search barber shops or places...",
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                                      suffixIcon: _searchQuery.isNotEmpty 
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 20),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                                _placePredictions = [];
                                                _showPredictions = false;
                                              });
                                            },
                                          ) 
                                        : null,
                                    ),
                                  ),
                                  // Predictions list removed from here
                                ],
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.2),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1.0,
                      child: child,
                    ),
                  ),
                );
              },
              child: (_viewingMap || _isNavigating) 
                ? const SizedBox.shrink() 
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip("Nearby", _selectedFilter == "Nearby", () {
                            setState(() => _selectedFilter = "Nearby");
                            _generateMarkers();
                          }),
                          const SizedBox(width: 8),
                          _buildFilterChip("Popular", _selectedFilter == "Popular", () {
                            setState(() => _selectedFilter = "Popular");
                            _generateMarkers();
                          }),
                          const SizedBox(width: 8),
                          _buildFilterChip("Top Rated", _selectedFilter == "Top Rated", () {
                            setState(() => _selectedFilter = "Top Rated");
                            _generateMarkers();
                          }),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            offset: const Offset(0, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (value) {
                              setState(() => _selectedFilter = value);
                              _generateMarkers();
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'Price: Low to High',
                                child: Text('Price: Low to High', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                              const PopupMenuItem(
                                value: 'Price: High to Low',
                                child: Text('Price: High to Low', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ],
                            child: _buildFilterChip(
                              _selectedFilter.startsWith('Price') ? _selectedFilter : "Price", 
                              _selectedFilter.startsWith('Price'), 
                              null // Handled by PopupMenuButton
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.emerald,
                child: _isLoading 
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                    )
                  : _viewingMap
                    ? _buildMapView()
                    : _filteredShops.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.6,
                            alignment: Alignment.center,
                            child: Text("No shops found", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filteredShops.length,
                          itemBuilder: (context, index) => _buildShopCard(_filteredShops[index]),
                        ),
              ),
            ),
          ],
        ),
      ),
        
        // Predictions Dropdown
        if (_showPredictions && _placePredictions.isNotEmpty)
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomLeft,
            showWhenUnlinked: false,
            offset: const Offset(0, 4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(20),
              color: isDark ? AppTheme.darkCardBG : Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width - 32 - 12 - 44, // Approx width adjustment
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBG : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _placePredictions.length,
                  itemBuilder: (context, index) {
                    final prediction = _placePredictions[index];
                    return ListTile(
                      leading: const Icon(Icons.place, size: 16),
                      title: Text(prediction.description, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                      onTap: () => _onPredictionSelected(prediction),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShopCard(BarberShop shop) {
    return InkWell(
      onTap: () async {
        final result = await context.push('/shop-preview', extra: shop);
        if (result == true) _handleBookingSuccess();
      },
      borderRadius: BorderRadius.circular(32),
      child: Container(
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
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        shop.address,
                        style: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_currentPosition != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          () {
                            final distance = Geolocator.distanceBetween(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                              (shop.coordinates['lat'] ?? 0).toDouble(),
                              (shop.coordinates['lng'] ?? 0).toDouble(),
                            );
                            if (distance < 1000) {
                              return "${distance.round()}m";
                            } else {
                              return "${(distance / 1000).toStringAsFixed(1)}km";
                            }
                          }(),
                          style: const TextStyle(
                            color: AppTheme.emerald,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildShopAction(LucideIcons.navigation, "NAVIGATE", isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFE8F0FE), Colors.blue, () async {
                      try {
                        // Show loading
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  SizedBox(width: 16),
                                  Text("Calculating professional route..."),
                                ],
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }

                        // 1. Get current position
                        final position = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high,
                        );
                        
                        // 2. Fetch route from backend
                        final apiService = ref.read(apiServiceProvider);
                        final routeData = await apiService.getNavigationRoute(
                          originLat: position.latitude, 
                          originLng: position.longitude, 
                          destLat: (shop.coordinates['lat'] ?? 0).toDouble(), 
                          destLng: (shop.coordinates['lng'] ?? 0).toDouble(),
                        );

                        if (routeData != null && routeData['status'] == 'success') {
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NavigationScreen(
                                  shop: shop,
                                  initialRoute: routeData,
                                  initialPosition: position,
                                ),
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Failed to fetch route. Opening legacy maps...")),
                            );
                            final fallbackUrl = 'https://www.google.com/maps/dir/?api=1&destination=${shop.coordinates['lat']},${shop.coordinates['lng']}';
                            launchUrl(Uri.parse(fallbackUrl));
                          }
                        }
                      } catch (e) {
                          debugPrint('❌ Navigation error: $e');
                      }
                    }),
                    const SizedBox(width: 12),
                    _buildShopAction(LucideIcons.calendar, "BOOK NOW", isDark ? AppTheme.darkAccent : AppTheme.lightAccent, Colors.white, () async {
                      final result = await context.push('/booking', extra: {'shop': shop});
                      if (result == true) _handleBookingSuccess();
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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

  Future<void> _fetchPredictions(String query) async {
    final predictions = await _mapServices.getPlacePredictions(query);
    setState(() {
      _placePredictions = predictions;
      _showPredictions = true;
    });
  }

  Future<void> _onPredictionSelected(services.PlacePrediction prediction) async {
    setState(() {
      _searchQuery = prediction.description;
      _searchController.text = prediction.description; // Populate search bar
      _showPredictions = false;
      FocusScope.of(context).unfocus();
    });

    final latLng = await _mapServices.getPlaceDetails(prediction.placeId);
    if (latLng != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      
      // Add a temporary marker for the selected place
      // And fetch directions if current location is known
      if (_currentPosition != null) {
        _fetchDirections(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), latLng);
      }
    }
  }

  Future<void> _fetchDirections(LatLng origin, LatLng destination) async {
    try {
      PolylinePoints polylinePoints = PolylinePoints();
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _mapServices.apiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.status == 'OK') {
        // Calculate distance and travel time
        double distanceInMeters = Geolocator.distanceBetween(
          origin.latitude, origin.longitude, 
          destination.latitude, destination.longitude
        );
        double distanceInKm = distanceInMeters / 1000;
        int minutes = (distanceInKm / 0.5).round(); // Assume 30km/h avg speed for demo
        if (minutes < 1) minutes = 1;

        final arrivalTime = DateTime.now().add(Duration(minutes: minutes));

        setState(() {
          _navigationDistance = "${distanceInKm.toStringAsFixed(1)} km";
          _navigationDuration = "$minutes min";
          _navigationArrivalTime = DateFormat('h:mm a').format(arrivalTime);
          
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
            color: const Color(0xFF4285F4), // Google Maps Blue
            width: 6,
          ));
        });
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    }
  }

  Widget _buildNavigationHeader() {
    if (!_isNavigating || _navigationShop == null) return const SizedBox.shrink();
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F9D58), // Google Maps Green
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.navigation, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "towards",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _navigationShop!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.mic, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationFooter() {
    if (!_isNavigating) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _navigationDuration,
                    style: const TextStyle(
                      color: Color(0xFF0F9D58),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$_navigationDistance • $_navigationArrivalTime",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Exit Button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isNavigating = false;
                  _polylines.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD93025), // Google Maps Red
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Exit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateMarkers() async {
    final Set<Marker> markers = {};
    
    for (final shop in _filteredShops) {
       final lat = shop.coordinates['lat'];
       final lng = shop.coordinates['lng'];
       if (lat == null || lng == null) continue;

       final icon = await _createCustomMarkerBitmap(shop.photos.isNotEmpty ? shop.photos[0] : null);

       markers.add(Marker(
         markerId: MarkerId(shop.id),
         position: LatLng(lat, lng),
         icon: icon,
         onTap: () async {
            // Get screen coordinate
            if (_mapController != null) {
              final ScreenCoordinate screenCoordinate = await _mapController!.getScreenCoordinate(LatLng(lat, lng));
              
              setState(() {
                 _popupPosition = Offset(screenCoordinate.x.toDouble(), screenCoordinate.y.toDouble());
                 _selectedMapShop = shop;
              });
            } else {
               setState(() => _selectedMapShop = shop);
            }
            
            // Also fetch directions if needed
            if (_currentPosition != null) {
              _fetchDirections(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
                LatLng(lat, lng)
              );
            }
         },
       ));
    }
    
    if (mounted) {
      setState(() => _customMarkers = markers);
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(String? url) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const int size = 150; // Pixel size
    final Paint paint = Paint()..color = AppTheme.emerald;
    final Paint borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 10;

    // Draw Circle Background
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    // Draw Image
    if (url != null) {
      try {
        final Uint8List? imageBytes = await _loadImageBytes(url);
        if (imageBytes != null) {
           final ui.Codec codec = await ui.instantiateImageCodec(imageBytes, targetWidth: size, targetHeight: size);
           final ui.FrameInfo fi = await codec.getNextFrame();
           
           canvas.save();
           // Clip Path for Circle
           final Path clipPath = Path()..addOval(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
           canvas.clipPath(clipPath);
           canvas.drawImage(fi.image, Offset.zero, Paint());
           canvas.restore();
        }
      } catch (e) {
        debugPrint('Error loading marker image: $e');
      }
    }

    // Draw Border
    canvas.drawCircle(const Offset(size / 2, size / 2), (size / 2) - 5, borderPaint);

    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(size, size);
    final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData != null) {
      return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
    }
    return BitmapDescriptor.defaultMarker;
  }
  
  Future<Uint8List?> _loadImageBytes(String url) async {
    try {
      String resolvedUrl = url;
      if (!url.startsWith('http')) {
        // Construct base URL from AppConfig (remove /api/v1 if present for uploads)
        // Assuming uploads are at root /uploads, and API is at /api/v1
        String baseUrl = Platform.isAndroid ? AppConfig.getBaseUrl() : AppConfig.getIosBaseUrl();
        // Remove /api/v1 suffix if it exists to get root
        baseUrl = baseUrl.replaceAll('/api/v1', '');
        
        if (!url.startsWith('/')) {
          resolvedUrl = '$baseUrl/$url';
        } else {
          resolvedUrl = '$baseUrl$url';
        }
      }
      
      debugPrint('Fetching marker image from: $resolvedUrl');
      final response = await http.get(Uri.parse(resolvedUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error fetching image bytes: $e');
    }
    return null;
  }

  Widget _buildMapView() {
    // Regenerate markers if filtered list changes
    // Optimization: Call _generateMarkers() in setState where _searchQuery changes instead of rebuild
    // But for now, let's keep it simple. If valid keys don't match, we might need to trigger.
    // Actually best to trigger _generateMarkers in _loadData and onChanged.
    
    final LatLng center = _currentPosition != null 
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(40.7128, -74.0060); // Default to NYC if unknown

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: GoogleMap(
              mapType: _isNavigating ? MapType.normal : _currentMapType,
              initialCameraPosition: CameraPosition(target: center, zoom: 14),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              trafficEnabled: _isNavigating ? true : _trafficEnabled,
              markers: _isNavigating && _navigationShop != null
                ? {
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: LatLng(_navigationShop!.coordinates['lat']!, _navigationShop!.coordinates['lng']!),
                      infoWindow: InfoWindow(title: _navigationShop!.name),
                    ),
                    if (_currentPosition != null)
                      Marker(
                        markerId: const MarkerId('current_pos'),
                        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      ),
                  }
                : (_selectedMapShop != null ? {..._customMarkers, Marker(
                    markerId: const MarkerId('selected'),
                    position: LatLng(_selectedMapShop!.coordinates['lat']!, _selectedMapShop!.coordinates['lng']!),
                  )} : _customMarkers),
              polylines: _polylines,
              onTap: (latLng) {
                if (!_isNavigating) {
                  setState(() {
                    _selectedMapShop = null;
                    _showPredictions = false;
                    FocusScope.of(context).unfocus();
                  });
                }
              },
              onCameraMove: (position) {
                if (!_isNavigating && (_selectedMapShop != null || _showPredictions)) {
                  setState(() {
                    _selectedMapShop = null;
                    _showPredictions = false;
                    FocusScope.of(context).unfocus();
                  });
                }
              },
            ),
          ),
        ),
        
        // Google Maps Style Navigation Overlays
        if (_isNavigating) ...[
          _buildNavigationHeader(),
          _buildNavigationFooter(),
        ],
        
        // Map Controls - Hidden during active navigation
        if (!_isNavigating)
          Positioned(
            top: 20,
            right: 32,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'mapType',
                  backgroundColor: isDark ? AppTheme.darkCardBG : Colors.white,
                  child: Icon(Icons.layers, color: isDark ? Colors.white : Colors.black),
                  onPressed: () {
                    setState(() {
                      _currentMapType = _currentMapType == MapType.normal 
                        ? MapType.hybrid 
                        : MapType.normal;
                    });
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'traffic',
                  backgroundColor: _trafficEnabled ? AppTheme.emerald : (isDark ? AppTheme.darkCardBG : Colors.white),
                  child: Icon(Icons.traffic, color: _trafficEnabled ? Colors.white : (isDark ? Colors.white : Colors.black)),
                  onPressed: () {
                    setState(() {
                      _trafficEnabled = !_trafficEnabled;
                    });
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'myLocation',
                  backgroundColor: isDark ? AppTheme.darkCardBG : Colors.white,
                  child: Icon(Icons.my_location, color: isDark ? Colors.white : Colors.black),
                  onPressed: () {
                    if (_currentPosition != null && _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude))
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  backgroundColor: isDark ? AppTheme.darkCardBG : Colors.white,
                  child: Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'zoomOut',
                backgroundColor: isDark ? AppTheme.darkCardBG : Colors.white,
                child: Icon(Icons.remove, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                },
              ),
            ],
          ),
        ),
        
        // Shop Card Overlay - Dynamic Positioning
        if (_selectedMapShop != null && _popupPosition != null)
          Positioned(
            left: _popupPosition!.dx - 140, // Center: Width 280 / 2
            top: _popupPosition!.dy - 150,  // Above marker: Card Height (~100) + Marker Size (~50)
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  alignment: Alignment.bottomCenter,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () async {
                  final result = await context.push('/shop-preview', extra: _selectedMapShop);
                  if (result == true) _handleBookingSuccess();
                },
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBG : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                           ClipRRect(
                             borderRadius: BorderRadius.circular(12),
                             child: UniversalImage(
                               imagePath: _selectedMapShop!.photos.isNotEmpty ? _selectedMapShop!.photos[0] : null,
                               height: 50,
                               width: 50,
                               fit: BoxFit.cover,
                             ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Text(
                                   _selectedMapShop!.name,
                                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                                 Text(
                                   _selectedMapShop!.address,
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                   style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6)),
                                 ),
                                 const SizedBox(height: 2),
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Row(
                                       children: [
                                         Icon(LucideIcons.star, size: 10, color: AppTheme.emerald),
                                         const SizedBox(width: 2),
                                         Text(
                                           _selectedMapShop!.rating.toStringAsFixed(1),
                                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: isDark ? Colors.white : Colors.black),
                                         ),
                                       ],
                                     ),
                                     if (_currentPosition != null)
                                       Text(
                                         () {
                                           final distance = Geolocator.distanceBetween(
                                             _currentPosition!.latitude,
                                             _currentPosition!.longitude,
                                             (_selectedMapShop!.coordinates['lat'] ?? 0).toDouble(),
                                             (_selectedMapShop!.coordinates['lng'] ?? 0).toDouble(),
                                           );
                                           return distance < 1000 ? "${distance.round()}m" : "${(distance / 1000).toStringAsFixed(1)}km";
                                         }(),
                                         style: const TextStyle(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                                       ),
                                   ],
                                 ),
                               ],
                             ),
                           ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAppointmentsTab() {
    final categories = [
      {'id': 'PENDING', 'label': 'Pending'},
      {'id': 'AWAITING_CUSTOMER_CONFIRMATION', 'label': 'Confirm (₹1)'},
      {'id': 'CONFIRMED', 'label': 'Accepted'},
      {'id': 'COMPLETED', 'label': 'Completed'},
      {'id': 'CANCELLED', 'label': 'Cancelled'}
    ];

    final filtered = _appointments.where((a) {
      final statusStr = a.status.name.replaceAll(RegExp(r'(?=[A-Z])'), '_').toUpperCase();
      print('🔍 [FILTER] Appt ${a.id}: status=${a.status.name} -> parsed=$statusStr vs filter=$_activeAppointmentFilter');
      
      if (_activeAppointmentFilter == 'CANCELLED') {
        return statusStr.contains('CANCELLED');
      }
      return statusStr == _activeAppointmentFilter;
    }).toList();

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
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.emerald,
            child: filtered.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      alignment: Alignment.center,
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
                    ),
                  )
                : ListView.builder(
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCardBG : Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(24),
                                border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : Border.all(color: Colors.black.withOpacity(0.05)),
                              ),
                              child: Column(
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: UniversalImage(
                                    imagePath: shop.photos.isNotEmpty ? shop.photos[0] : null,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
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
                            // Show Pay ₹1 button for AWAITING_CUSTOMER_CONFIRMATION
                            if (_activeAppointmentFilter == 'AWAITING_CUSTOMER_CONFIRMATION')
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  children: [
                                    if (appt.expiresAt != null)
                                      Builder(
                                        builder: (context) {
                                          final remaining = appt.expiresAt!.difference(DateTime.now());
                                          if (remaining.isNegative) {
                                            return const Padding(
                                              padding: EdgeInsets.only(bottom: 8.0),
                                              child: Text('EXPIRED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                            );
                                          }
                                          final minutes = remaining.inMinutes;
                                          final seconds = remaining.inSeconds % 60;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Text(
                                              'Confirm within ${minutes}:${seconds.toString().padLeft(2, '0')}',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    InkWell(
                                      onTap: () async {
                                        setState(() => _isLoading = true);
                                        try {
                                          final apiService = ref.read(apiServiceProvider);
                                          // 1. Create Order on Backend
                                          final orderResponse = await apiService.post(
                                            '/payments/create-order?booking_id=${appt.id}', 
                                            {}
                                          );
                                          
                                          if (mounted) {
                                            _startRazorpayCheckout(orderResponse.data, appt.id);
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to initiate payment: $e')),
                                            );
                                          }
                                        } finally {
                                          if (mounted) setState(() => _isLoading = false);
                                        }
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(LucideIcons.creditCard, size: 16, color: Colors.green.shade700),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Pay ₹1 to Confirm Slot',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Show Rate button for completed appointments
                            if (_activeAppointmentFilter == 'COMPLETED')
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: InkWell(
                                  onTap: () {
                                    context.push('/submit-review', extra: {
                                      'shopId': appt.shopId,
                                      'staffId': appt.staffId,
                                      'shopName': shop.name,
                                      'staffName': 'your barber',
                                    });
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(LucideIcons.star, size: 16, color: Colors.amber.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Rate Your Experience',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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
    final user = ref.watch(userProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
          child: Row(
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
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.emerald,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                photoUrl: user?.profilePhoto,
                                name: user?.name ?? "User",
                                radius: 50,
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
                          Text(user?.name ?? "User Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 4),
                           // Opacity(opacity: 0.6, child: Text(user?.phone ?? "", style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileItem(LucideIcons.user, "Edit Profile", isDark ? Colors.amber : AppTheme.lightAccent, () {
                    context.push('/edit-profile');
                  }),
                  _buildProfileItem(LucideIcons.shield, "Manage Permissions", isDark ? Colors.amber : AppTheme.lightAccent, () {
                    context.push('/manage-permissions');
                  }),
                  _buildProfileItem(LucideIcons.fileText, "Privacy Policy", isDark ? Colors.amber : AppTheme.lightAccent, () {
                    _showPrivacyPolicyDialog(context);
                  }),
                  _buildProfileItem(LucideIcons.trash2, "Delete Account", Colors.red, () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Account?'),
                        content: const Text('This action is permanent and will remove all your booking history.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () async {
                              await ref.read(userProvider.notifier).setUser(null);
                              if (mounted) {
                                Navigator.pop(context);
                                context.go('/login');
                              }
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 40),
                  // Logout Button
                  InkWell(
                    onTap: () async {
                      await ref.read(userProvider.notifier).setUser(null);
                      if (mounted) {
                        context.go('/login');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: const [
                          Icon(LucideIcons.logOut, color: Colors.red, size: 24),
                          const SizedBox(width: 16),
                          Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 17)),
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
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.fileText,
                      color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Privacy Policy",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  """
1. Introduction
Welcome to BarberBook24. We respect your privacy and are committed to protecting your personal data.

2. Data We Collect
We collect information you provide directly to us, such as your name, phone number, and profile picture when you register.

3. How We Use Your Data
- To provide and maintain our service.
- To manage your account and bookings.
- To communicate with you about updates to the service.

4. Data Security
We implement appropriate security measures to protect your personal data.

5. Your Rights
You have the right to access, correct, or delete your personal data at any time through the app settings.

6. Contact Us
If you have any questions about this Privacy Policy, please contact our support team.
                  """,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.8),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkButton : AppTheme.lightButton,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback? onTap) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected 
            ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent)
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
              ? Colors.white
              : (isDark ? Colors.white : Colors.black).withOpacity(0.5),
        ),
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.95),
        border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 70, // Fixed height for consistency
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(0, LucideIcons.home, "Home"),
              _buildNavItem(1, LucideIcons.calendar, "Bookings", badgeCount: ref.watch(unreadNotificationCountProvider)),
              _buildNavItem(2, LucideIcons.user, "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    bool isActive = _currentIndex == index;
    Color accentColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    Color color = isActive ? accentColor : (isDark ? Colors.white : Colors.black).withOpacity(0.4);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? accentColor.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: isActive ? 24 : 22,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
