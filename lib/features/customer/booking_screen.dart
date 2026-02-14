import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/widgets/user_avatar.dart';
import 'package:customer_sync/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/widgets/universal_image.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final BarberShop shop;
  final Staff? initialStaff;

  const BookingScreen({
    super.key,
    required this.shop,
    this.initialStaff,
  });

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  String _step = 'services';
  final List<Staff> _selectedStaffList = [];
  final List<String> _selectedServiceIds = [];
  String? _selectedDate;
  String? _selectedSlot;
  BarberShop? _refreshedShop;
  BarberShop get _currentShop => _refreshedShop ?? widget.shop;
  bool _isBooking = false;
  bool _isLoadingShop = false;

  String _getDateLabel(String dateStr) {
    try {
      final now = DateTime.now();
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      // Strip time from both for accurate comparison
      final today = DateTime(now.year, now.month, now.day);
      final compareDate = DateTime(date.year, date.month, date.day);
      final difference = compareDate.difference(today).inDays;
      
      if (difference == 0) return 'Today';
      if (difference == 1) return 'Tomorrow';
      return DateFormat('E, d').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialStaff != null) {
      _selectedStaffList.add(widget.initialStaff!);
      _step = 'services';
    }
    // Ensure _selectedDate is ALWAYS an ISO format, even if it persists incorrectly
    if (_selectedDate == null || _selectedDate == 'Today' || _selectedDate == 'Tomorrow') {
      _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    _fetchFullShopDetails();
  }

  Future<void> _fetchFullShopDetails() async {
    setState(() => _isLoadingShop = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final shopData = await apiService.getShop(widget.shop.id);
      if (shopData != null && mounted) {
        setState(() {
          _refreshedShop = BarberShop.fromJson(shopData);
          _isLoadingShop = false;
        });
        debugPrint('✅ Fetched full shop details for ${_currentShop.name}. Staff count: ${_currentShop.staff.length}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching full shop details: $e');
      if (mounted) setState(() => _isLoadingShop = false);
    }
  }

  void _handleBack() {
    if (_isBooking) return;
    setState(() {
      if (_step == 'summary') _step = 'slot';
      else if (_step == 'slot') {
        if (widget.initialStaff != null) _step = 'services';
        else _step = 'staff';
      }
      else if (_step == 'staff') _step = 'services';
      else if (_step == 'services') context.pop();
      else context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBGStart : AppTheme.lightBGStart,
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(isDark),
                ),
              ),
              _buildFooter(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    String title = "Booking";
    if (_step == 'staff') title = "Select a Barber";
    else if (_step == 'services') title = "Select Services";
    else if (_step == 'slot') title = "Pick a Time";
    else if (_step == 'summary') title = "Booking Summary";

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          InkWell(
            onTap: _handleBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.arrowLeft, size: 20, color: isDark ? Colors.white : Colors.black),
            ),
          ),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    if (_step == 'staff') return _buildStaffSelector(isDark);
    if (_step == 'services') return _buildServiceSelector(isDark);
    if (_step == 'slot') return _buildSlotSelector(isDark);
    if (_step == 'summary') return _buildSummary(isDark);
    return const SizedBox();
  }

  void _showBarberDetails(Staff staff, bool isDark) {
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    // Safe access for hot-reload resilience
    final String skillsData = (staff.skills as dynamic) ?? '';
    final skills = skillsData.isNotEmpty 
        ? skillsData.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    // Map staff service IDs to full Service objects
    final staffServices = _currentShop.services
        .where((s) => staff.services.contains(s.id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBGMiddle : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50, height: 5,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    UserAvatar(radius: 70, photoUrl: staff.imageUrl, name: staff.name),
                    const SizedBox(height: 24),
                    Text(staff.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${staff.role} • ${staff.experience} Years Exp.",
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _prepStatItem(isDark, LucideIcons.star, staff.rating.toString(), "Rating"),
                        Container(width: 1, height: 30, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 15)),
                        _prepStatItem(isDark, LucideIcons.messageSquare, staff.reviewsCount.toString(), "Reviews"),
                        if (staff.experience > 0) ...[
                          Container(width: 1, height: 30, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 15)),
                          _prepStatItem(isDark, LucideIcons.history, staff.experience.toString(), "Years Exp"),
                        ],
                      ],
                    ),

                    if (skills.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const _SectionHeader(title: "EXPERTISE"),
                      const SizedBox(height: 16),
                      // ... (Wrapped content)
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          )).toList(),
                        ),
                      ),
                    ],

                    if (staff.workingHours.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const _SectionHeader(title: "WORKING HOURS"),
                      const SizedBox(height: 16),
                      _buildWorkingHoursSection(isDark, staff),
                    ],

                    if (staffServices.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const _SectionHeader(title: "SERVICE MENU"),
                      const SizedBox(height: 16),
                      ...staffServices.map((s) => _buildServiceMenuItem(isDark, s, accentColor)),
                    ],

                    if (staff.description.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const _SectionHeader(title: "ABOUT ME"),
                      const SizedBox(height: 16),
                      Text(
                        staff.description,
                        textAlign: TextAlign.left,
                        style: TextStyle(height: 1.6, fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7)),
                      ),
                    ],

                    if (staff.workPhotos.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const _SectionHeader(title: "PORTFOLIO"),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: staff.workPhotos.length,
                          itemBuilder: (context, i) => Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: UniversalImage(imagePath: staff.workPhotos[i]),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 64),
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text("CLOSE PREVIEW", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prepStatItem(bool isDark, IconData icon, String val, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: icon == LucideIcons.star ? Colors.amber : (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
      ],
    );
  }

  Widget _buildWorkingHoursSection(bool isDark, Staff staff) {
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: days.map((day) {
          final isWorking = staff.workingDays.contains(day);
          final hours = staff.workingHours[day];
          String timeStr = "Closed";
          if (isWorking) {
             if (hours != null) {
               final start = hours['start'] ?? '';
               final end = hours['end'] ?? '';
               if (start.isNotEmpty && end.isNotEmpty) {
                 timeStr = "$start - $end";
               } else {
                 timeStr = "Available";
               }
             } else {
               timeStr = "Available";
             }
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day, style: TextStyle(fontWeight: isWorking ? FontWeight.bold : FontWeight.normal, color: isWorking ? (isDark ? Colors.white : Colors.black) : Colors.grey)),
                Text(timeStr, style: TextStyle(fontWeight: isWorking ? FontWeight.bold : FontWeight.normal, color: isWorking ? AppTheme.emerald : Colors.grey)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServiceMenuItem(bool isDark, Service service, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(LucideIcons.scissors, color: accentColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text("${service.duration} mins", style: TextStyle(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              ],
            ),
          ),
          Text("\$${service.price.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: accentColor)),
        ],
      ),
    );
  }

  Widget _buildStaffSelector(bool isDark) {
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final List<Staff> relevantStaff;
    try {
      relevantStaff = _currentShop.staff.where((s) {
        // Safe check for isAvailable
        if (s.isAvailable == false) return false;
        if (_selectedServiceIds.isEmpty) return true;
        // Ensure the barber offers ALL selected services
        return _selectedServiceIds.every((id) => (s.services).contains(id));
      }).toList();
    } catch (e) {
      debugPrint('Error filtering staff: $e');
      return Center(child: Text('Error loading barbers: $e'));
    }

    if (_isLoadingShop && relevantStaff.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (relevantStaff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.userX, size: 64, color: accentColor.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              "No barbers found for these services",
              style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => setState(() => _step = 'services'),
              child: Text("Change Services", style: TextStyle(color: accentColor)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      key: const ValueKey('staff'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const ClampingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: relevantStaff.length,
      itemBuilder: (context, index) {
        final staff = relevantStaff[index];
        bool isSelected = _selectedStaffList.any((s) => s.id == staff.id);
        
        final matchingServices = _currentShop.services
            .where((s) => _selectedServiceIds.contains(s.id) && staff.services.contains(s.id))
            .map((s) => s.name)
            .toList();

        return InkWell(
          onTap: () => setState(() {
            if (isSelected) {
              _selectedStaffList.removeWhere((s) => s.id == staff.id);
            } else {
              _selectedStaffList.add(staff);
            }
          }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isSelected ? accentColor : Colors.transparent, 
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _showBarberDetails(staff, isDark),
                      child: UserAvatar(
                        radius: 40,
                        photoUrl: staff.imageUrl,
                        name: staff.name,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.check, size: 12, color: Colors.white),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.info, size: 12, color: accentColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  staff.name, 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black, fontSize: 13),
                ),
                Text(
                  staff.role, 
                  style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                ),
                const SizedBox(height: 8),
                if (matchingServices.isNotEmpty)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "MATCHES:",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: accentColor),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: matchingServices.map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(s, style: TextStyle(fontSize: 8, color: accentColor, fontWeight: FontWeight.bold)),
                              )).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      staff.rating.toString(), 
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceSelector(bool isDark) {
    // If we have selected ANY staff, show services offered by ALL selected staff?
    // Or just show all shop services and highlight those matching?
    // Given the sequence is Services First, this only matters if initialStaff is set.
    
    final List<Service> availableServices;
    if (_selectedStaffList.isNotEmpty) {
      // Show services that AT LEAST ONE of the selected staff provides
      final allStaffServiceIds = _selectedStaffList.expand((s) => s.services).toSet();
      availableServices = _currentShop.services.where((s) => allStaffServiceIds.contains(s.id)).toList();
    } else {
      availableServices = _currentShop.services;
    }

    return ListView.builder(
      key: const ValueKey('services'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: availableServices.length,
      itemBuilder: (context, index) {
        final service = availableServices[index];
        bool isSelected = _selectedServiceIds.contains(service.id);
        return InkWell(
          onTap: () => setState(() {
            if (isSelected) _selectedServiceIds.remove(service.id);
            else _selectedServiceIds.add(service.id);
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isSelected ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)),
                  ),
                  child: isSelected ? const Icon(LucideIcons.check, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      Text("${service.duration} min", style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                    ],
                  ),
                ),
                Text("\$${service.price}", style: const TextStyle(color: AppTheme.darkAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlotSelector(bool isDark) {
    final now = DateTime.now();
    final dates = List.generate(7, (index) {
      final date = now.add(Duration(days: index));
      return DateFormat('yyyy-MM-dd').format(date);
    });

    final slots = [
      '09:00 AM', '10:00 AM', '11:00 AM', '11:30 AM', 
      '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM',
      '05:00 PM', '06:00 PM'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("SELECT DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                bool isSelected = _selectedDate == dates[index];
                return InkWell(
                  onTap: () => setState(() => _selectedDate = dates[index]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: isSelected ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) : (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(_getDateLabel(dates[index]), style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Text("SELECT SLOT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              bool isSelected = _selectedSlot == slots[index];
              return InkWell(
                onTap: () => setState(() => _selectedSlot = slots[index]),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) : (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(slots[index], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    double total = _currentShop.services.where((s) => _selectedServiceIds.contains(s.id)).fold(0.0, (sum, s) => sum + s.price);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: _selectedStaffList.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: UserAvatar(
                            radius: 20,
                            photoUrl: _selectedStaffList[index].imageUrl,
                            name: _selectedStaffList[index].name,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("WITH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                          Text(
                            _selectedStaffList.length == 1 
                                ? _selectedStaffList.first.name 
                                : "${_selectedStaffList.length} Barbers", 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSummaryRow(isDark, "Date & Time", "${_selectedDate != null ? _getDateLabel(_selectedDate!) : ''} • $_selectedSlot"),
                const SizedBox(height: 16),
                _buildSummaryRow(isDark, "Services", _selectedServiceIds.length.toString()),
                 Divider(height: 32, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Amount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("\$$total", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.darkAccent)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(bool isDark, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    bool canProceed = false;
    String buttonText = "Next";

    if (_step == 'staff') {
      canProceed = _selectedStaffList.isNotEmpty;
    } else if (_step == 'services') {
      canProceed = _selectedServiceIds.isNotEmpty;
    } else if (_step == 'slot') {
      canProceed = _selectedDate != null && _selectedSlot != null;
    } else if (_step == 'summary') {
      canProceed = true;
      buttonText = "Confirm & Book";
    }


    return Container(
      padding: const EdgeInsets.all(24),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          disabledBackgroundColor: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.3),
        ),
        onPressed: (canProceed && !_isBooking) ? () async {
          if (_step == 'services') {
            if (widget.initialStaff != null) {
              setState(() => _step = 'slot');
            } else {
              setState(() => _step = 'staff');
            }
          } else if (_step == 'staff') {
            setState(() => _step = 'slot');
          } else if (_step == 'slot') {
            setState(() => _step = 'summary');
          } else if (_step == 'summary') {
            setState(() => _isBooking = true);
            try {
              final apiService = ref.read(apiServiceProvider);
              final user = ref.read(userProvider);
              if (user == null) {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("You must be logged in to book")),
                  );
                }
                return;
              }
              
              // SUPER DEFENSIVE DATE CHECK
              String actualDate = _selectedDate!;
              if (actualDate == "Today") {
                actualDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
              } else if (actualDate == "Tomorrow") {
                actualDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
              }

              final bookingData = {
                'shopId': _currentShop.id,
                'staffId': _selectedStaffList.first.id,
                'staffIds': _selectedStaffList.map((s) => s.id).toList(),
                'customerId': user.id,
                'services': _selectedServiceIds,
                'date': actualDate,
                'timeSlot': _selectedSlot!,
                'notes': 'Booked via Customer App',
              };

              debugPrint('🚀 [BOOKING] Sending request payload: $bookingData');

              final appt = await apiService.createBooking(bookingData);
              
              if (appt != null) {
                if (mounted) context.pop(true); // Return true to signal refresh
              } else {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to create booking. Please try again.")),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            } finally {
              if (mounted) setState(() => _isBooking = false);
            }
          }
        } : null,
        child: _isBooking 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey)),
    );
  }
}
