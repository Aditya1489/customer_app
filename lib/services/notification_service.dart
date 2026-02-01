import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/services/api_service.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));
final refreshTriggerProvider = StateProvider((ref) => 0);
final unreadNotificationCountProvider = StateProvider((ref) => 0);

class NotificationService {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _pollingTimer;
  final Set<String> _alertedIds = {};

  NotificationService(this._ref);

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        print("Notification tapped: ${details.payload}");
      },
    );
    
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    await androidImplementation?.requestNotificationsPermission();
  }

  void startPolling(String userId) {
    _pollingTimer?.cancel();
    // Poll every 5 seconds for responsive updates in customer app
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkNotifications(userId));
    // Check immediately
    _checkNotifications(userId);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> _checkNotifications(String userId) async {
    print("Checking notifications for user: $userId");
    try {
      final apiService = _ref.read(apiServiceProvider);
      final notifications = await apiService.getNotifications(userId);
      print("Fetched ${notifications.length} notifications from server");
      
      bool foundNew = false;
      int unreadCount = 0;
      for (final notif in notifications) {
        if (!notif['isRead']) {
          unreadCount++;
          print("Found unread notification: ${notif['id']} - ${notif['title']}");
        }
        
        // Check if unread and not already alerted
        if (!notif['isRead'] && !_alertedIds.contains(notif['id'])) {
          print("🚨 Alerting user about new notification: ${notif['title']}");
          _showLocalNotification(notif);
          _alertedIds.add(notif['id']);
          foundNew = true;
        }
      }

      _ref.read(unreadNotificationCountProvider.notifier).state = unreadCount;

      if (foundNew) {
        print("Triggering UI refresh due to new notifications");
        _ref.read(refreshTriggerProvider.notifier).state++;
      }
    } catch (e) {
      print("❌ Error polling notifications: $e");
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notif) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'customer_sync_notifications',
      'CustomerSync Notifications',
      channelDescription: 'Notifications for appointment updates',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id: notif['id'].hashCode,
      title: notif['title'],
      body: notif['body'],
      notificationDetails: platformChannelSpecifics,
      payload: notif['data'].toString(),
    );
  }
}
