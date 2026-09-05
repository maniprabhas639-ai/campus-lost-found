import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/routes/app_router.dart';
import '../../core/routes/app_routes.dart';
import '../../data/models/lost_found_item.dart';
import '../../data/services/firestore_service.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'Background notification: '
    '${message.notification?.title} - '
    '${message.notification?.body}',
  );
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirestoreService? firestoreService,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _firestoreService = firestoreService ?? FirestoreService();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirestoreService _firestoreService;

  Map<String, dynamic>? _pendingNavigationData;
  bool _isProcessingNavigation = false;

  static const AndroidNotificationChannel _notificationChannel =
      AndroidNotificationChannel(
    'campusfind_notifications',
    'CampusFind Notifications',
    description: 'Notifications from CampusFind.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }

    await _initializeLocalNotifications();
    await _createNotificationChannel();

    final NotificationSettings settings =
        await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      'Notification permission: ${settings.authorizationStatus}',
    );

    final String? token = await _messaging.getToken();

    debugPrint('FCM TOKEN: $token');

    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationOpened,
    );

    final RemoteMessage? initialMessage =
        await _messaging.getInitialMessage();

    if (initialMessage != null) {

      debugPrint(
        'Initial notification received: ${initialMessage.messageId}',
      );

      if (initialMessage.data.isNotEmpty) {
        _pendingNavigationData =
            Map<String, dynamic>.from(initialMessage.data);

        _schedulePendingNavigation();
      } else {
        debugPrint(
          'Initial notification contains no navigation data.',
        );
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
  }

  Future<void> _createNotificationChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      _notificationChannel,
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
      'Foreground notification: '
      '${message.notification?.title} - '
      '${message.notification?.body}',
    );

    final RemoteNotification? notification = message.notification;

    if (notification == null) {
      return;
    }

    final String? payload = message.data.isEmpty
        ? null
        : jsonEncode(message.data);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannel.id,
          _notificationChannel.name,
          channelDescription: _notificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _handleNotificationOpened(RemoteMessage message) async {
    debugPrint(
      'Notification opened: ${message.messageId}',
    );

    if (message.data.isEmpty) {
      debugPrint('Notification contains no navigation data.');
      return;
    }

    debugPrint(
      'Notification data: ${message.data}',
    );

    _pendingNavigationData =
        Map<String, dynamic>.from(message.data);

    _schedulePendingNavigation();
  }

  Future<void> _handleLocalNotificationResponse(
    NotificationResponse response,
  ) async {
    debugPrint(
      'Local notification opened: ${response.payload}',
    );

    final String? payload = response.payload;

    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    try {
      final dynamic decodedPayload = jsonDecode(payload);

      if (decodedPayload is! Map) {
        debugPrint('Invalid local notification payload.');
        return;
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(decodedPayload);

      _pendingNavigationData = data;

      _schedulePendingNavigation();
    } catch (error) {
      debugPrint(
        'LOCAL NOTIFICATION PAYLOAD ERROR: $error',
      );
    }
  }

  void _schedulePendingNavigation() {
    if (_pendingNavigationData == null ||
        _isProcessingNavigation) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingNavigation();
    });
  }

  Future<void> _processPendingNavigation() async {
    if (_pendingNavigationData == null ||
        _isProcessingNavigation) {
      return;
    }

    final GlobalKey<NavigatorState> navigatorKey =
        AppRouter.navigatorKey;

    final NavigatorState? navigator = navigatorKey.currentState;

    if (navigator == null) {
      debugPrint(
        'Navigator is not ready. Retrying notification navigation.',
      );

      _retryPendingNavigation();
      return;
    }

    final String? currentRoute = AppRouter.currentRouteName;

if (currentRoute != AppRoutes.home) {
  debugPrint(
    'Waiting for authenticated home route before '
    'notification navigation. Current route: $currentRoute',
  );

  _retryPendingNavigation();
  return;
}

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(_pendingNavigationData!);

    _pendingNavigationData = null;
    _isProcessingNavigation = true;

    try {
      await _navigateFromNotificationData(data);
    } finally {
      _isProcessingNavigation = false;
    }
  }

  void _retryPendingNavigation() {
    Future<void>.delayed(
      const Duration(milliseconds: 300),
      () {
        if (_pendingNavigationData == null ||
            _isProcessingNavigation) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processPendingNavigation();
        });
      },
    );
  }

  Future<void> _navigateFromNotificationData(
    Map<String, dynamic> data,
  ) async {
    final String? type = _readString(data['type']);

    if (type == null) {
      debugPrint('Notification type is missing.');
      return;
    }

    switch (type) {
      case 'message':
        await _navigateToChat(data);
        return;

      case 'item':
        await _navigateToItem(data);
        return;

      default:
        debugPrint(
          'Unknown notification type: $type',
        );
    }
  }

  Future<void> _navigateToChat(
    Map<String, dynamic> data,
  ) async {
    final String? conversationId =
        _readString(data['conversationId']);

    final String? itemId = _readString(data['itemId']);

    if (conversationId == null || itemId == null) {
      debugPrint(
        'Message notification is missing conversationId or itemId.',
      );
      return;
    }

    try {
      final LostFoundItem? item =
          await _firestoreService.getItemById(itemId);

      if (item == null) {
        debugPrint(
          'Notification item is no longer available: $itemId',
        );
        return;
      }

      final conversation =
          await _firestoreService.getConversation(
        conversationId: conversationId,
      );

      if (conversation == null) {
        debugPrint(
          'Notification conversation is no longer available: '
          '$conversationId',
        );
        return;
      }

      final NavigatorState? navigator =
          AppRouter.navigatorKey.currentState;

      if (navigator == null) {
        debugPrint(
          'Navigator became unavailable during chat navigation.',
        );

        _pendingNavigationData = data;
        _schedulePendingNavigation();
        return;
      }

      navigator.pushNamed(
        AppRoutes.chat,
        arguments: <String, dynamic>{
          'item': item,
          'conversationId': conversationId,
        },
      );

      debugPrint(
        'Notification navigation completed: chat',
      );
    } catch (error) {
      debugPrint(
        'NOTIFICATION CHAT NAVIGATION ERROR: $error',
      );
    }
  }

  Future<void> _navigateToItem(
    Map<String, dynamic> data,
  ) async {
    final String? itemId = _readString(data['itemId']);

    if (itemId == null) {
      debugPrint(
        'Item notification is missing itemId.',
      );
      return;
    }

    try {
      final LostFoundItem? item =
          await _firestoreService.getItemById(itemId);

      if (item == null) {
        debugPrint(
          'Notification item is no longer available: $itemId',
        );
        return;
      }

      final NavigatorState? navigator =
          AppRouter.navigatorKey.currentState;

      if (navigator == null) {
        debugPrint(
          'Navigator became unavailable during item navigation.',
        );

        _pendingNavigationData = data;
        _schedulePendingNavigation();
        return;
      }

      navigator.pushNamed(
        AppRoutes.itemDetails,
        arguments: item,
      );

      debugPrint(
        'Notification navigation completed: item $itemId',
      );
    } catch (error) {
      debugPrint(
        'NOTIFICATION ITEM NAVIGATION ERROR: $error',
      );
    }
  }

  String? _readString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final String trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return null;
    }

    return trimmedValue;
  }
}