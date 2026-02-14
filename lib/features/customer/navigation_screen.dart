import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:customer_sync/core/theme/app_theme.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  final BarberShop shop;
  final Map<String, dynamic> initialRoute;
  final Position initialPosition;

  const NavigationScreen({
    super.key,
    required this.shop,
    required this.initialRoute,
    required this.initialPosition,
  });

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  GoogleMapController? _mapController;
  late FlutterTts _flutterTts;
  
  // State for navigation
  late List<dynamic> _steps;
  late String _polylinePoints;
  int _currentStepIndex = 0;
  bool _isMuted = false;
  
  Position? _currentPosition;
  double _bearing = 0.0;
  double _tilt = 45.0;
  double _zoom = 18.0;
  
  StreamSubscription<Position>? _positionStream;
  
  // UI Info
  String _instruction = "";
  String _distanceToNext = "";
  String _eta = "";
  String _remainingDistance = "";
  String _arrivalTime = "";

  @override
  void initState() {
    super.initState();
    _steps = widget.initialRoute['steps'];
    _polylinePoints = widget.initialRoute['polyline'];
    _currentPosition = widget.initialPosition;
    _instruction = _steps[0]['instruction'];
    _flutterTts = FlutterTts();
    
    // Set portrait only for navigation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _initNavigation();
    _speak(_instruction);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _flutterTts.stop();
    // Reset orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _initNavigation() {
    // Start tracking location precisely
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // Update every 2 meters
    );
    
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _updateNavigation(position);
    });
    
    _updateUIInfo(widget.initialRoute);
  }

  void _updateUIInfo(Map<String, dynamic> route) {
     setState(() {
      _remainingDistance = route['total_distance'];
      _eta = route['total_duration'];
      
      // Calculate arrival time
      final durationSeconds = route['total_duration_seconds'] ?? 0;
      final arrival = DateTime.now().add(Duration(seconds: durationSeconds));
      final hour = arrival.hour > 12 ? arrival.hour - 12 : (arrival.hour == 0 ? 12 : arrival.hour);
      final ampm = arrival.hour >= 12 ? 'PM' : 'AM';
      _arrivalTime = "$hour:${arrival.minute.toString().padLeft(2, '0')} $ampm";
    });
  }

  Future<void> _speak(String text) async {
    if (_isMuted) return;
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  void _updateNavigation(Position position) {
    if (!mounted) return;

    setState(() {
      // Calculate bearing if we have previous pos
      if (_currentPosition != null) {
        _bearing = Geolocator.bearingBetween(
          _currentPosition!.latitude, _currentPosition!.longitude,
          position.latitude, position.longitude
        );
      }
      _currentPosition = position;
    });

    // Move camera
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          bearing: _bearing,
          tilt: _tilt,
          zoom: _zoom,
        ),
      ),
    );

    // Check progress on steps
    _checkStepProgress(position);
  }

  void _checkStepProgress(Position position) {
    if (_currentStepIndex >= _steps.length) return;

    final nextStep = _steps[_currentStepIndex];
    final nextTarget = nextStep['end_location'];
    
    double distanceToTurn = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      nextTarget['lat'], nextTarget['lng']
    );

    setState(() {
      if (distanceToTurn > 1000) {
        _distanceToNext = "${(distanceToTurn / 1000).toStringAsFixed(1)} km";
      } else {
        _distanceToNext = "${distanceToTurn.round()} m";
      }
    });

    // If within 50m of next turn/instruction point
    if (distanceToTurn < 50) {
      _advanceStep();
    }
    
    // Rerouting logic (If user is more than 50m from current step's start or end and not near polyline)
    // For simplicity, we'll just check if user is far from the next target and moving away
    // Real implementation would check distance to the polyline.
  }

  void _advanceStep() {
    if (_currentStepIndex < _steps.length - 1) {
       setState(() {
        _currentStepIndex++;
        _instruction = _steps[_currentStepIndex]['instruction'];
      });
      _speak(_instruction);
    }
  }

  Future<void> _recenter() async {
    if (_currentPosition == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          bearing: _bearing,
          tilt: _tilt,
          zoom: _zoom,
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmation() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBG : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Exit Navigation?", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text("Are you sure you want to stop the navigation?", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Resume", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Exit", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 3D Map
            _buildMap(),
            
            // Top Banner
            _buildTopBanner(),
            
            // Right Controls
            _buildRightControls(),
            
            // Bottom Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _decodePolyline(_polylinePoints),
        color: AppTheme.emerald,
        width: 8,
      ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.initialPosition.latitude, widget.initialPosition.longitude),
        zoom: _zoom,
        tilt: _tilt,
        bearing: _bearing,
      ),
      onMapCreated: (c) => _mapController = c,
      myLocationEnabled: false, // We'll show our own custom arrow
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      trafficEnabled: true,
      polylines: polylines,
      markers: {
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(_currentPosition?.latitude ?? 0, _currentPosition?.longitude ?? 0),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          rotation: _bearing, // Auto-pointing user marker
          flat: true,
          anchor: const Offset(0.5, 0.5),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.shop.coordinates['lat']!, widget.shop.coordinates['lng']!),
        ),
      },
    );
  }

  Widget _buildTopBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D5A3F), // Darker Premium Google Maps Green
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.navigation, color: Colors.white, size: 40),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _distanceToNext.isEmpty ? "Starting..." : _distanceToNext,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  Text(
                    _instruction,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightControls() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.3,
      child: Column(
        children: [
          _buildCircleButton(
            icon: LucideIcons.compass,
            onPressed: () {}, // Rotate map to North?
          ),
          const SizedBox(height: 12),
          _buildCircleButton(
            icon: _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
            onPressed: () => setState(() => _isMuted = !_isMuted),
          ),
          const SizedBox(height: 12),
          _buildCircleButton(
            icon: LucideIcons.locateFixed,
            onPressed: _recenter,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(28, 20, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, -10)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(_eta, style: const TextStyle(color: Color(0xFF1ED760), fontSize: 26, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      Text("• $_arrivalTime", style: const TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_remainingDistance, style: const TextStyle(color: Colors.white30, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                if (await _showExitConfirmation()) {
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C), // Deep Red
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Text(
                  "EXIT", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }
}
