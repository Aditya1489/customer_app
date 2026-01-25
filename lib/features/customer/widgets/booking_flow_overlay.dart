import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:intl/intl.dart';

class BookingFlowOverlay extends ConsumerStatefulWidget {
  final BarberShop shop;
  final Staff? initialStaff;
  final bool isDark;
  final VoidCallback onClose;
  final Function(Appointment appointment) onComplete;

  const BookingFlowOverlay({
    super.key,
    required this.shop,
    this.initialStaff,
    required this.isDark,
    required this.onClose,
    required this.onComplete,
  });

  @override
  ConsumerState<BookingFlowOverlay> createState() => _BookingFlowOverlayState();
}

class _BookingFlowOverlayState extends ConsumerState<BookingFlowOverlay> {
  String _step = 'staff';
  Staff? _selectedStaff;
  final List<String> _selectedServiceIds = [];
  String? _selectedDate;
  String? _selectedSlot;

  @override
  void initState() {
    super.initState();
    if (widget.initialStaff != null) {
      _selectedStaff = widget.initialStaff;
      _step = 'services';
    }
  }

  void _handleBack() {
    setState(() {
      if (_step == 'summary') _step = 'slot';
      else if (_step == 'slot') _step = 'services';
      else if (_step == 'services') {
        if (widget.initialStaff != null) widget.onClose();
        else _step = 'staff';
      } else widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        isDark: widget.isDark,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.arrowLeft, size: 20, color: widget.isDark ? Colors.white : Colors.black),
            ),
          ),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 'staff') return _buildStaffSelector();
    if (_step == 'services') return _buildServiceSelector();
    if (_step == 'slot') return _buildSlotSelector();
    if (_step == 'summary') return _buildSummary();
    return const SizedBox();
  }

  Widget _buildStaffSelector() {
    return GridView.builder(
      key: const ValueKey('staff'),
      physics: const ClampingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: widget.shop.staff.length,
      itemBuilder: (context, index) {
        final staff = widget.shop.staff[index];
        bool isSelected = _selectedStaff?.id == staff.id;
        return InkWell(
          onTap: () => setState(() {
            _selectedStaff = staff;
            _step = 'services';
          }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: isSelected ? AppTheme.darkButton : Colors.transparent, width: 2),
            ),
            child: Column(
              children: [
                CircleAvatar(radius: 40, backgroundImage: NetworkImage(staff.imageUrl)),
                const SizedBox(height: 12),
                Text(staff.name, style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
                Text(staff.role, style: TextStyle(fontSize: 10, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.star, size: 12, color: Colors.yellow),
                    const SizedBox(width: 4),
                    Text(staff.rating.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceSelector() {
    // Filter services that the specific staff provides (in mock it might be all, but we check)
    final availableServices = widget.shop.services.where((s) => _selectedStaff?.services.contains(s.id) ?? true).toList();

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
              color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isSelected ? AppTheme.darkButton : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.darkButton : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.2)),
                  ),
                  child: isSelected ? Icon(LucideIcons.check, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name, style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
                      Text("${service.duration} min", style: TextStyle(fontSize: 12, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4))),
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

  Widget _buildSlotSelector() {
    final now = DateTime.now();
    final dates = List.generate(7, (index) {
      final date = now.add(Duration(days: index));
      if (index == 0) return 'Today';
      if (index == 1) return 'Tomorrow';
      return DateFormat('E, d').format(date);
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
          Text("SELECT DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4))),
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
                      color: isSelected ? AppTheme.darkButton : (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(dates[index], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (widget.isDark ? Colors.white : Colors.black))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Text("SELECT SLOT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4))),
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
                    color: isSelected ? AppTheme.darkButton : (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(slots[index], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (widget.isDark ? Colors.white : Colors.black))),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    double total = widget.shop.services.where((s) => _selectedServiceIds.contains(s.id)).fold(0, (sum, s) => sum + s.price);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 30, backgroundImage: NetworkImage(_selectedStaff!.imageUrl)),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("WITH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                        Text(_selectedStaff!.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSummaryRow("Date & Time", "$_selectedDate • $_selectedSlot"),
                const SizedBox(height: 16),
                _buildSummaryRow("Services", _selectedServiceIds.length.toString()),
                 Divider(height: 32, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.1)),
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

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.5))),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
      ],
    );
  }

  Widget _buildFooter() {
    bool canProceed = false;
    String buttonText = "Next";

    if (_step == 'staff') {
      canProceed = _selectedStaff != null;
    } else if (_step == 'services') {
      canProceed = _selectedServiceIds.isNotEmpty;
    } else if (_step == 'slot') {
      canProceed = _selectedDate != null && _selectedSlot != null;
    } else if (_step == 'summary') {
      canProceed = true;
      buttonText = "Confirm & Book";
    }

    if (_step == 'staff') return const SizedBox(); // No footer needed for staff selection as it auto-advances

    return Container(
      padding: const EdgeInsets.all(24),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkButton,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          disabledBackgroundColor: AppTheme.darkButton.withOpacity(0.3),
        ),
        onPressed: canProceed ? () {
          setState(() {
            if (_step == 'services') _step = 'slot';
            else if (_step == 'slot') _step = 'summary';
            else if (_step == 'summary') {
              // Create appointment object and complete
              final user = ref.read(userProvider);
              final appt = Appointment(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                shopId: widget.shop.id,
                staffId: _selectedStaff!.id,
                customerId: user.id,
                services: _selectedServiceIds,
                date: _selectedDate!,
                timeSlot: _selectedSlot!,
                status: AppointmentStatus.pending,
                totalAmount: widget.shop.services.where((s) => _selectedServiceIds.contains(s.id)).fold(0, (sum, s) => sum + s.price),
                totalDuration: widget.shop.services.where((s) => _selectedServiceIds.contains(s.id)).fold(0, (sum, s) => sum + s.duration),
                bookedAt: DateTime.now().toIso8601String(),
              );
              widget.onComplete(appt);
            }
          });
        } : null,
        child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}
