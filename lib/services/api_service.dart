import 'dart:io';
import 'package:dio/dio.dart';
import 'package:customer_sync/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/core/config/app_config.dart';
import 'package:customer_sync/core/utils/logger.dart';

final apiServiceProvider = Provider((ref) => ApiService());

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: Platform.isAndroid 
        ? AppConfig.getBaseUrl() 
        : AppConfig.getIosBaseUrl(),
    connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
    receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
  ));

  // OTP Authentication
  Future<bool> requestOtp(String phone) async {
    try {
      final response = await _dio.post('/auth/otp/request', data: {
        'phone': phone,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error requesting OTP', e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> verifyOtp(String phone, String code) async {
    try {
      final response = await _dio.post('/auth/otp/verify', data: {
        'phone': phone,
        'code': code,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error verifying OTP', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> selectRole(String userId, String role, String shopId) async {
    try {
      final response = await _dio.post('/auth/login/select-role', data: {
        'user_id': userId,
        'role': role,
        'shop_id': shopId,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error selecting role', e);
      return null;
    }
  }

  Future<List<BarberShop>> getShops() async {
    try {
      final response = await _dio.get('/shops');
      if (response.statusCode == 200) {
        final List data = response.data;
        return data.map((e) => BarberShop.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching shops', e);
      return [];
    }
  }

  Future<List<Appointment>> getAppointments(String userId) async {
    if (userId.isEmpty) {
      AppLogger.error('getAppointments called with empty userId');
      return [];
    }
    try {
      final response = await _dio.get('/bookings/', queryParameters: {'customer_id': userId});
      if (response.statusCode == 200) {
        final List data = response.data;
        return data.map((e) => Appointment.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching appointments', e);
      return [];
    }
  }

  Future<Appointment?> createBooking(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/bookings/', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Appointment.fromJson(response.data);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error creating booking', e);
      return null;
    }
  }

  Future<User?> updateProfile(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) {
      AppLogger.error('updateProfile called with empty userId');
      return null;
    }
    try {
      final response = await _dio.put('/profile/$userId', data: data);
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating profile', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> registerUser(String token, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error registering user', e);
      return null;
    }
  }

  Future<String?> getNavigationLink(String shopId, {double? lat, double? lng}) async {
    if (shopId.isEmpty) {
      AppLogger.error('getNavigationLink called with empty shopId');
      return null;
    }
    try {
      final response = await _dio.get(
        '/shops/$shopId/navigation',
        queryParameters: {
          if (lat != null) 'customer_lat': lat,
          if (lng != null) 'customer_lng': lng,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data['googleMapsUrl'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching navigation link', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> updatePermissions(String userId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/profile/$userId/permissions', data: data);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating permissions', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOwnerAnalytics(String ownerId, {String? period, String? shopId}) async {
    try {
      final response = await _dio.get(
        '/analytics/owner/$ownerId',
        queryParameters: {
          if (period != null) 'period': period.toLowerCase(),
          if (shopId != null) 'shop_id': shopId,
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching owner analytics', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStaffEarnings(String staffId, {String? period}) async {
    try {
      final response = await _dio.get(
        '/analytics/staff/$staffId/earnings',
        queryParameters: {
          if (period != null) 'period': period.toLowerCase(),
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching staff earnings', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStaffProfile(String staffId) async {
    if (staffId.isEmpty) {
      AppLogger.error('getStaffProfile called with empty staffId');
      return null;
    }
    try {
      final response = await _dio.get('/shops/staff/$staffId/profile');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching staff profile', e);
      return null;
    }
  }

  Future<List<dynamic>> getNotifications(String userId) async {
    if (userId.isEmpty) {
      AppLogger.error('getNotifications called with empty userId');
      return [];
    }
    try {
      final response = await _dio.get('/notifications/$userId');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching notifications', e);
      return [];
    }
  }

  Future<void> markNotificationAsRead(String notifId) async {
    try {
      await _dio.put('/notifications/$notifId/read');
    } catch (e) {
      AppLogger.error('Error marking notification read', e);
    }
  }

  Future<String?> uploadFile(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post('/uploads', data: formData);
      if (response.statusCode == 200 && response.data != null) {
        // Return the full URL
        final String? relativeUrl = response.data['url'] as String?;
        if (relativeUrl != null) {
          final String baseUrl = _dio.options.baseUrl.replaceAll('/api/v1', '');
          return '$baseUrl$relativeUrl';
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('Error uploading file', e);
      return null;
    }
  }

  String get baseUrl => _dio.options.baseUrl.replaceAll('/api/v1', '');

  String? resolveUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    if (path.startsWith('assets/')) return null;
    
    // DON'T resolve if it's an absolute local path
    if (path.startsWith('/data/') || path.startsWith('/Users/') || path.startsWith('/var/')) {
      return path; 
    }
    
    // Ensure relative paths from server are full URLs
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    
    if (cleanBaseUrl.isEmpty) return cleanPath;
    
    return '$cleanBaseUrl$cleanPath';
  }

  // Submit a review for a staff/shop
  Future<Map<String, dynamic>?> submitReview(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/reviews/', data: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error submitting review', e);
      return null;
    }
  }

  // Get navigation route from backend (uses secure Google Directions API proxy)
  Future<Map<String, dynamic>?> getNavigationRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final response = await _dio.get(
        '/navigation/route',
        queryParameters: {
          'origin_lat': originLat,
          'origin_lng': originLng,
          'dest_lat': destLat,
          'dest_lng': destLng,
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching navigation route', e);
      return null;
    }
  }

  // Shop Management
  Future<Map<String, dynamic>?> getShop(String shopId) async {
    try {
      final response = await _dio.get('/shops/$shopId');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching shop', e);
      return null;
    }
  }

  Future<List<dynamic>> getShopServices(String shopId) async {
    try {
      final response = await _dio.get('/shops/$shopId/services');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching shop services', e);
      return [];
    }
  }

  Future<List<dynamic>> getPopularServices(String shopId) async {
    try {
      final response = await _dio.get('/shops/$shopId/services/popular');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching popular services', e);
      return [];
    }
  }

  Future<List<dynamic>> getShopStaff(String shopId) async {
    try {
      final response = await _dio.get('/shops/$shopId/staff');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching shop staff', e);
      return [];
    }
  }

  // Shop Reviews
  Future<List<dynamic>> getShopReviews(String shopId) async {
    try {
      final response = await _dio.get('/reviews/shop/$shopId');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching shop reviews', e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getShopReviewStats(String shopId) async {
    try {
      final response = await _dio.get('/reviews/shop/$shopId/stats');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching shop review stats', e);
      return null;
    }
  }

  // Generic POST method
  Future<Response> post(String path, Map<String, dynamic> data) async {
    return await _dio.post(path, data: data);
  }
}
