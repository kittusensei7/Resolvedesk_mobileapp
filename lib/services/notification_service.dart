import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/api_config.dart';
import '../pages/complaint_details_page.dart';

// Top-level background handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 [FCM Background] ${message.notification?.title}: ${message.notification?.body}");
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'complaint_alerts_v4',
    'Complaint Alerts',
    description: 'High priority alert notifications for newly assigned complaints.',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('resolvedesk_chime'),
    enableVibration: true,
    enableLights: true,
  );

  /// Navigates directly to the ComplaintDetailsPage for a given complaint ID
  static void navigateToComplaint(String? complaintIdStr, [int retryCount = 0]) {
    if (complaintIdStr == null || complaintIdStr.trim().isEmpty) return;
    final id = int.tryParse(complaintIdStr.trim());
    if (id == null) return;

    if (navigatorKey.currentState != null) {
      debugPrint("🚀 [FCM Click] Navigating directly to Complaint #$id");
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ComplaintDetailsPage(complaintId: id),
        ),
      );
    } else if (retryCount < 10) {
      debugPrint("⏳ [FCM Click] Navigator not ready yet, retrying for Complaint #$id (attempt ${retryCount + 1})...");
      Future.delayed(const Duration(milliseconds: 400), () {
        navigateToComplaint(complaintIdStr, retryCount + 1);
      });
    }
  }

  /// Initializes Firebase messaging and local notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    // 1. Request notification permission (Required for Android 13+ and iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('🔔 [FCM] Notification authorization status: ${settings.authorizationStatus}');

    // 2. Setup Android local notification channel for foreground alerts
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("🔔 [LocalNotification Click] Payload: ${details.payload}");
        navigateToComplaint(details.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    // Explicit runtime permission dialog on Android 13+ (Tiramisu, API 33+)
    await androidPlugin?.requestNotificationsPermission();

    await androidPlugin?.createNotificationChannel(_channel);

    // 3. Foreground message listener (Shows banner and plays custom sound when app is actively open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("🔔 [FCM Foreground] Received: ${message.notification?.title}");
      RemoteNotification? notification = message.notification;
      final complaintId = message.data['complaintId']?.toString();

      if (notification != null && !kIsWeb) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'complaint_alerts_v4',
              'Complaint Alerts',
              channelDescription: 'High priority alert notifications for newly assigned complaints.',
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('resolvedesk_chime'),
              enableVibration: true,
              enableLights: true,
            ),
          ),
          payload: complaintId,
        );
      }
    });

    // 4. App in background/minimized tapped by user
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("🔔 [FCM onMessageOpenedApp] Notification tapped: ${message.data}");
      navigateToComplaint(message.data['complaintId']?.toString());
    });

    // 5. App completely closed / terminated and launched by tapping notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("🔔 [FCM getInitialMessage] Launched from terminated state: ${initialMessage.data}");
      Future.delayed(const Duration(milliseconds: 600), () {
        navigateToComplaint(initialMessage.data['complaintId']?.toString());
      });
    }

    // 6. Token refresh listener
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 [FCM] Token refreshed: $newToken");
      syncTokenWithServer(newToken);
    });

    _initialized = true;
  }

  /// Syncs the device token to the Paradesk backend
  static Future<void> syncTokenWithServer([String? explicitToken]) async {
    try {
      final token = explicitToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint("⚠️ [FCM] No FCM token received from Google Play Services.");
        return;
      }

      debugPrint("==================================================");
      debugPrint("📱 TECHNICIAN FCM TOKEN:");
      debugPrint(token);
      debugPrint("==================================================");

      final user = await ApiConfig.getUser();
      final authToken = await ApiConfig.getToken();
      if (user == null || authToken == null || authToken.isEmpty) {
        debugPrint("ℹ️ [FCM] User session not active yet. Token will sync upon login.");
        return;
      }

      final dio = await ApiConfig.getDio();
      final response = await dio.post(
        'technicians/fcm-token',
        data: {'fcmToken': token},
      );

      if (response.statusCode == 200) {
        debugPrint("✅ [FCM] Device token registered with Paradesk backend successfully!");
      }
    } catch (e) {
      debugPrint("❌ [FCM] Error registering FCM token with server: $e");
    }
  }
}
