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

  Future<Map<String, dynamic>?> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      AppLogger.error('Login called with empty email or password');
      return null;
    }
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error logging in', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> register(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/auth/register', data: data);
      if (response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error registering', e);
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
}
