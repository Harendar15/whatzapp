import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:adchat/helpers/local_storage.dart';
import '../../views/chat/chat_screen.dart';
import '../../views/call/call_screen.dart';

class PushNotificationController extends GetxController {
  final _firestore = FirebaseFirestore.instance;

  // ---------------- SAVE DEVICE TOKEN ----------------
 Future<void> saveDeviceToken(String uid) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

   final deviceId = LocalStorage.getDeviceId();
if (deviceId == null || deviceId.isEmpty) return;


    await _firestore
        .collection("deviceTokens")
        .doc(uid)
        .collection("devices")
        .doc(deviceId)
        .set({
      "token": token,
      "platform": defaultTargetPlatform.name,
      "updatedAt": FieldValue.serverTimestamp(),
    });

  } catch (e) {
    debugPrint("❌ saveDeviceToken error: $e");
  }
}



  // ---------------- SEND CHAT PUSH ----------------
  Future<void> sendChatPush({
    required String uid,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    final functions = FirebaseFunctions.instanceFor(
      region: 'asia-south1',
    );

try {
  await functions.httpsCallable("sendPush").call({
    "uid": uid,
    "title": title,
    "body": body,
    "payload": data,
  });
} catch (e) {
  debugPrint("⚠️ Push failed (ignored): $e");
}


  }

  // ---------------- SEND CALL PUSH ----------------
  Future<void> sendCallPush({
  required String targetUid,
  required String callerName,
  required String channelName,
  required String callType,
}) async {
  final functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  await functions.httpsCallable("sendCallNotification").call({
    "targetUid": targetUid,
    "callerName": callerName,
    "channelName": channelName,
    "callType": callType,
  });
}


  // ---------------- HANDLE NOTIFICATION TAP ----------------
  void selectContact(String payload) {
    try {
      final data = jsonDecode(payload);

      if (data['type'] == 'chat') {
        Get.toNamed(
          ChatScreen.routeName,
          arguments: {
            'name': data['name'],
            'uid': data['uid'],
            'isGroupChat': false,
            'isCommunityChat': false,
            'profilePic': data['profilePic'],
            'isHideChat': false,
          },
        );
      }

      if (data['type'] == 'call') {
        Get.toNamed(CallScreen.routeName, arguments: data);
      }
    } catch (e) {
      debugPrint("❌ selectContact error: $e");
    }
  }
}
