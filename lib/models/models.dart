enum AppRole {
  customer,
  barber,
  owner,
}

enum AppointmentStatus {
  pending,
  awaitingCustomerConfirmation,
  confirmed,
  inProgress,
  completed,
  cancelledByCustomer,
  cancelledByBarber,
  noShow,
  expired,
}

class Service {
  final String id;
  final String name;
  final double price;
  final int duration;
  final String? imageUrl;

  Service({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    this.imageUrl,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      duration: json['duration'],
      imageUrl: json['imageUrl'],
    );
  }
}

class Staff {
  final String id;
  final String name;
  final String role;
  final int experience;
  final double rating;
  final int reviewsCount;
  final String description;
  final String imageUrl;
  final List<String> workPhotos;
  final List<String> services;
  final String? shopId;

  final bool isAvailable;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.experience,
    required this.rating,
    required this.reviewsCount,
    required this.description,
    required this.imageUrl,
    required this.workPhotos,
    required this.services,
    this.shopId,
    this.isAvailable = true,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      experience: json['experience'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewsCount: json['reviewsCount'] ?? 0,
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      workPhotos: List<String>.from(json['workPhotos'] ?? []),
      services: List<String>.from(json['services'] ?? []),
      shopId: json['shopId'],
      isAvailable: json['isAvailable'] ?? true,
    );
  }
}

class BarberShop {
  final String id;
  final String name;
  final String address;
  final String description;
  final double rating;
  final int reviewsCount;
  final List<String> photos;
  final Map<String, double> coordinates;
  final List<Staff> staff;
  final List<Service> services;

  BarberShop({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.rating,
    required this.reviewsCount,
    required this.photos,
    required this.coordinates,
    required this.staff,
    required this.services,
  });

  factory BarberShop.fromJson(Map<String, dynamic> json) {
    return BarberShop(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewsCount: json['reviewsCount'] ?? 0,
      photos: List<String>.from(json['photos'] ?? []),
      coordinates: Map<String, double>.from(json['coordinates'] ?? {}),
      staff: (json['staff'] as List? ?? []).map((e) => Staff.fromJson(e)).toList(),
      services: (json['services'] as List? ?? []).map((e) => Service.fromJson(e)).toList(),
    );
  }
}

class Appointment {
  final String id;
  final String shopId;
  final String staffId;
  final String customerId;
  final List<String> services;
  final String date;
  final String timeSlot;
  final AppointmentStatus status;
  final double totalAmount;
  final int totalDuration;
  final String bookedAt;

  Appointment({
    required this.id,
    required this.shopId,
    required this.staffId,
    required this.customerId,
    required this.services,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.totalAmount,
    required this.totalDuration,
    required this.bookedAt,
    this.expiresAt,
  });

  final DateTime? expiresAt;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? '',
      shopId: json['shopId'] ?? '',
      staffId: json['staffId'] ?? '',
      customerId: json['customerId'] ?? '',
      services: List<String>.from(json['services'] ?? []),
      date: json['date'] ?? '',
      timeSlot: json['timeSlot'] ?? '',
      status: AppointmentStatus.values.firstWhere(
        (e) {
          final normalizedName = e.name.replaceAll(RegExp(r'(?=[A-Z])'), '_').toUpperCase();
          return normalizedName == (json['status'] as String).replaceAll(' ', '_').toUpperCase();
        },
        orElse: () => AppointmentStatus.pending,
      ),
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      totalDuration: json['totalDuration'] ?? 0,
      bookedAt: json['bookedAt'] ?? '',
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
    );
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final AppRole role;
  final String? profilePhoto;
  final Map<String, bool> permissions;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profilePhoto,
    required this.permissions,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: AppRole.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['role'] ?? 'CUSTOMER'),
        orElse: () => AppRole.customer,
      ),
      profilePhoto: json['profilePhoto'],
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
    );
  }
}
