// ignore_for_file: avoid_print

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static FirebaseMessaging? firebaseMessaging;

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    if (kDebugMode) print('Background message Id : ${message.messageId}');
    print('Background message Time : ${message.sentTime}');
  }

  static Future<void> initializeNotification() async {
    print('Firebase notification initialized message');
    firebaseMessaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    NotificationSettings notificationSettings = await firebaseMessaging!.requestPermission(announcement: true);

    if (notificationSettings.authorizationStatus == AuthorizationStatus.authorized) {
      print('PERMISSION GRANTED');

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage remoteMessage) async {
          print('message title: ${remoteMessage.notification!.title}, body: ${remoteMessage.notification!.body}');

          AndroidNotificationDetails androidNotificationDetails = const AndroidNotificationDetails('CHANNEL ID', 'CHANNEL NAME',
              channelDescription: 'CHANNEL DESCRIPTION',
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              enableLights: true);
          DarwinNotificationDetails iosNotificationDetails = const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );
          NotificationDetails notificationDetails =
              NotificationDetails(android: androidNotificationDetails, iOS: iosNotificationDetails);
          if (remoteMessage.notification?.title != null && remoteMessage.notification?.body != null) {
            await flutterLocalNotificationsPlugin.show(
              0,
              remoteMessage.notification!.title!,
              remoteMessage.notification!.body!,
              notificationDetails,
            );
          }
        },
      );
    }
    await setFirebaseToken();

    await initializeLocalNotification();

    print('setFirebaseToken message');
  }

  static initializeLocalNotification() {
    AndroidInitializationSettings android = const AndroidInitializationSettings('@mipmap/ic_launcher');
    DarwinInitializationSettings ios = const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    InitializationSettings platform = InitializationSettings(android: android, iOS: ios);
    flutterLocalNotificationsPlugin.initialize(platform);
    print('Listening local notification');
  }

  static Future<void> setFirebaseToken() async {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM Token --> $fcmToken');
  }
}
