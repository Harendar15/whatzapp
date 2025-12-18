import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Screens
import 'views/home/home_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/otp_screen.dart';
import 'views/auth/user_information_screen.dart';
import 'views/select_contacts/select_contacts_screen.dart';
import 'views/status/confirm_status_screen.dart';
import 'views/status/status_contacts_screen.dart';
import 'views/home/settings_screen.dart';
import 'views/call/call_tab_screen.dart';
import 'views/splash/splash_screen.dart';
import 'views/welcome/welcome_screen.dart';
import 'views/call/select_contact_for_call_screen.dart';
import 'views/group/create_group_screen.dart';
import 'views/group/add_group_member_screen.dart';
import 'views/group/group_chat_screen.dart';
import 'views/call/call_screen.dart';
import 'package:adchat/crypto/session_manager.dart';
// Controllers
import 'controller/auth/login_controller.dart';
import 'controller/call/call_controller.dart';
import 'controller/notification/push_notification_controller.dart';

// Utils
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'utils/language/local_string.dart';
import 'helpers/local_storage.dart';
import 'call_routes.dart';

import 'package:uuid/uuid.dart';

/// ---------------------------------------------------------------
/// 🔹 BACKGROUND FCM HANDLER (TOP LEVEL ONLY)
/// ---------------------------------------------------------------
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint("📩 BG Notification → ${message.notification?.title}");
  debugPrint("📩 BG DATA → ${message.data}");
}

/// ---------------------------------------------------------------
/// 🔹 LOCAL NOTIFICATION SETUP
/// ---------------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> setupNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      if (details.payload != null &&
          Get.isRegistered<PushNotificationController>()) {
        Get.find<PushNotificationController>()
            .selectContact(details.payload!);
      }
    },
  );

  // -------------------------------
  // CHAT NOTIFICATION CHANNEL
  // -------------------------------
  const AndroidNotificationChannel chatChannel =
      AndroidNotificationChannel(
    'adchat_channel',
    'Chat Messages',
    description: 'Chat notifications',
    importance: Importance.high,
  );

  // -------------------------------
  // 📞 INCOMING CALL CHANNEL
  // -------------------------------
  const AndroidNotificationChannel incomingCallChannel =
      AndroidNotificationChannel(
    'incoming_calls',
    'Incoming Calls',
    description: 'Audio & Video calls',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('ringtone'),
    enableVibration: true,
  );

  final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(chatChannel);
    await androidPlugin.createNotificationChannel(incomingCallChannel);
  }

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  
  // -------------------------------
  // FOREGROUND CHAT NOTIFICATION
  // -------------------------------
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'adchat_channel',
            'Chat Messages',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  });

  // -------------------------------
  // NOTIFICATION TAP HANDLER
  // -------------------------------
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (Get.isRegistered<PushNotificationController>()) {
      Get.find<PushNotificationController>()
          .selectContact(jsonEncode(message.data));
    }
  });
}

/// ---------------------------------------------------------------
/// 🔹 FIREBASE SAFE INIT
/// ---------------------------------------------------------------
Future<void> initializeFirebaseSafe() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

/// ---------------------------------------------------------------
/// 🔹 MAIN
/// ---------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  

  await initializeFirebaseSafe();
  await GetStorage.init();

  // Device ID
  final existing = LocalStorage.getDeviceId();
  if (existing == null || existing.isEmpty) {
    final newId = const Uuid().v4();
    LocalStorage.saveDeviceId(newId);
    debugPrint("🆔 DeviceId generated: $newId");
  }

  // Controllers
  Get.put(LoginController());
  Get.put(CallController(), permanent: true);
  Get.put(PushNotificationController(), permanent: true); // ✅ IMPORTANT

  // Background FCM
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await setupNotifications();

  runApp(const ProviderScope(child: MyApp()));
}

/// ---------------------------------------------------------------
/// 🔹 APP ROOT
/// ---------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 800),
      minTextAdapt: true,
      builder: (_, __) => GetMaterialApp(
        title: 'AdChat',
        debugShowCheckedModeBanner: false,

        theme: Themes.light,
        darkTheme: Themes.dark,

        translations: LocalString(),
        locale: const Locale("en", "US"),

        home: const SplashScreen(),

        getPages: [
          GetPage(
              name: SplashScreen.routeName,
              page: () => const SplashScreen()),
          GetPage(
              name: WelcomeScreen.routeName,
              page: () => const WelcomeScreen()),
          GetPage(
              name: LoginScreen.routeName,
              page: () => const LoginScreen()),
          GetPage(
              name: OTPScreen.routeName,
              page: () => const OTPScreen()),
          GetPage(name: '/home', page: () => const HomeScreen()),
          GetPage(
              name: '/user-information',
              page: () => const UserInformationScreen()),

          ...CallRoutes.pages,

          GetPage(
              name: SelectContactsScreen.routeName,
              page: () => const SelectContactsScreen()),
          GetPage(
              name: SettingsScreen.routeName,
              page: () => SettingsScreen()),
          GetPage(
              name: StatusContactsScreen.routeName,
              page: () => const StatusContactsScreen()),
          GetPage(
              name: SelectContactForCallScreen.routeName,
              page: () => const SelectContactForCallScreen()),

          GetPage(
            name: ConfirmStatusScreen.routeName,
            page: () {
              final file = Get.arguments as File;
              return ConfirmStatusScreen(file: file);
            },
          ),

          GetPage(
              name: '/create-group-screen',
              page: () => const CreateGroupScreen()),

          GetPage(
            name: '/add-group-members',
            page: () {
              final args = Get.arguments as Map<String, dynamic>;
              return AddGroupMemberScreen(
                groupId: args['groupId'],
                membersUid: List<String>.from(args['membersUid']),
                fetchContacts: args['fetchContacts'],
              );
            },
          ),

          GetPage(
            name: '/group-chat',
            page: () {
              final args = Get.arguments as Map<String, dynamic>;
              return GroupChatScreen(
                groupId: args['groupId'],
                groupName: args['groupName'],
              );
            },
          ),

          GetPage(
              name: CallTabScreen.routeName,
              page: () => CallTabScreen()),
        ],

        builder: (context, widget) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaleFactor: 1.0),
            child: widget ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
