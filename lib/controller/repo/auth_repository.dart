// lib/controller/repo/auth_repository.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:adchat/controller/controller/auth_controller.dart';
import 'package:adchat/views/home/home_screen.dart';
import '../../models/user_model.dart';
import '../../helpers/prefs_services.dart';
import '../auth/login_controller.dart';
import '../storage/common_firebase_storage_repository.dart';
import '../../views/auth/otp_screen.dart';
import '../../helpers/local_storage.dart';
import '../../crypto/identity_key_manager.dart';
import '../../crypto/session_manager.dart';

import 'package:adchat/views/auth/login_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  ),
);

class AuthRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  AuthRepository({
    required this.auth,
    required this.firestore,
  });

  // --- Exposed getters ---
  String? get currentUid => auth.currentUser?.uid;
  /// ✅ REAL DEVICE ID (USED EVERYWHERE IN E2E)
  String get currentDeviceId {
    final deviceId = LocalStorage.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      throw Exception('❌ DeviceId missing in LocalStorage');
    }
    return deviceId;
  }


DateTime? _lastOtpAttempt;

bool _canVerifyOtp() {
  if (_lastOtpAttempt == null) return true;
  return DateTime.now()
      .difference(_lastOtpAttempt!)
      .inSeconds > 3;
}

//   /// Device id - prefer one from LocalStorage if present, otherwise a safe fallback.
// String get currentDeviceId {
//   final uid = auth.currentUser?.uid;
//   return uid != null ? "primary_$uid" : "unknown_device";
// }

  // convenient controller instance (must be registered in main)
  LoginController get controller => Get.find<LoginController>();

  int? _resendToken;

  // ---------------- Helper ----------------
  void _showSnack(BuildContext context, String message) {
    if (!context.mounted) {
      debugPrint("Snack (no context): $message");
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- User data helpers ----------------

  Future<UserModel?> getCurrentUserData() async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint("getCurrentUserData error: $e");
      return null;
    }
  }

  Stream<UserModel> userData(String id) {
    return firestore.collection("users").doc(id).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return UserModel.fromMap(snap.data()!);
      } else {
        return UserModel(
          name: "",
          uid: id,
          profilePic: "",
          about: "",
          phoneNumber: "",
          isOnline: false,
        );
      }
    });
  }

  // ---------------- Phone auth (real OTP) ----------------

  Future<void> signInWithPhone(BuildContext context, String phoneNumber) async {
    controller.isLoading.value = true;
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          controller.isLoading.value = false;
          try {
            await auth.signInWithCredential(credential);
            await _routeAfterSignIn();
          } catch (e) {
            debugPrint("auto sign-in error: $e");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          controller.isLoading.value = false;
          _showSnack(context, e.message ?? "Phone verification failed");
        },
      codeSent: (String verificationId, int? resendToken) {
          controller.isLoading.value = false;
          _resendToken = resendToken;
          controller.verificationId.value = verificationId;
          Get.toNamed(
            OTPScreen.routeName,
            arguments: {
              'verificationId': verificationId, // ✅ ONLY SOURCE
              'phoneNumber': phoneNumber,
            },
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint("codeAutoRetrievalTimeout: $verificationId");
        },
      );
    } catch (e) {
      controller.isLoading.value = false;
      debugPrint("signInWithPhone error: $e");
      _showSnack(context, 'Phone Sign-in Failed');
    }
  }

  /// ✅ RESEND OTP
  Future<void> resendOtp({
    required BuildContext context,
    required String phoneNumber,
  }) async {
    controller.isLoading.value = true;
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          controller.isLoading.value = false;
          try {
            await auth.signInWithCredential(credential);
            await _routeAfterSignIn();
          } catch (e) {
            debugPrint("resend auto sign-in error: $e");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          controller.isLoading.value = false;
          _showSnack(context, e.message ?? "Resend failed");
        },
      codeSent: (String verificationId, int? resendToken) {
          _resendToken = resendToken;
          controller.verificationId.value = verificationId;
          Get.offNamed(
            OTPScreen.routeName,
            arguments: {
              'phoneNumber': phoneNumber,
            },
          );
        },


        codeAutoRetrievalTimeout: (String verificationId) {
          controller.isLoading.value = false;
          debugPrint("resend codeAutoRetrievalTimeout: $verificationId");
        },
      );
    } catch (e) {
      controller.isLoading.value = false;
      debugPrint("resendOtp error: $e");
      _showSnack(context, 'Failed to resend OTP');
    }
  }

Future<void> verifyOTP({
  required BuildContext context,
  required String otp,
  required String verificationId,
  required String phoneNumber,
}) async {
  controller.isVerifyCode.value = true;

  try {
    if (verificationId.isEmpty) {
      _showSnack(context, "Verification expired. Please resend OTP.");
      return;
    }

    if (otp.length != 6) {
      _showSnack(context, "Invalid OTP");
      return;
    }
    if (!_canVerifyOtp()) {
  _showSnack(context, "Please wait before retrying");
  return;
}
_lastOtpAttempt = DateTime.now();

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );

    final userCredential = await auth.signInWithCredential(credential);

    final uid = userCredential.user!.uid;
    final phone = userCredential.user!.phoneNumber ?? phoneNumber;

    await firestore.collection('users').doc(uid).set({
      'uid': uid,
      'phoneNumber': phone,
      'profileCompleted': false,
      'isOnline': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _routeAfterSignIn();

  } on FirebaseAuthException catch (e) {
    _showSnack(context, e.message ?? "OTP verification failed");
  } finally {
    controller.isVerifyCode.value = false;
  }
}


  /// 🔥 STREAM: Get all users except me (for calls, contacts list, etc.)
  Stream<List<UserModel>> allUsers() {
    final myUid = auth.currentUser?.uid;
    if (myUid == null) return const Stream.empty();

    return firestore.collection('users').snapshots().map(
      (snap) {
        return snap.docs
            .map((d) => UserModel.fromMap(d.data()))
            .where((u) => u.uid != myUid)
            .toList();
      },
    );
  }


Future<void> resetE2EIfNeeded() async {
  const storage = FlutterSecureStorage();

  // 🔐 Identity keys
  await storage.delete(key: 'identity_key');
  await storage.delete(key: 'identity_pub');
  await storage.delete(key: 'signed_prekey');
  await storage.delete(key: 'prekeys');

  // 🔥 DELETE ALL SESSIONS
  final allKeys = await storage.readAll();
  for (final k in allKeys.keys) {
    if (k.startsWith('session_')) {
      await storage.delete(key: k);
    }
  }

  clearSessionCache();

  debugPrint('🧹 E2E identity + sessions wiped');
}



  // ---------------- Post sign-in routing ----------------
Future<void> _routeAfterSignIn() async {
    final user = auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

  // save uid
  LocalStorage.saveMyUid(uid);
  // after FirebaseAuth signIn / signUp success

  final lastUid = await LocalStorage.getMyUid();
    if (lastUid != null && lastUid != uid) {
        await resetE2EIfNeeded(); // 🔐 account switched
      }

  // ✅ SAME DEVICE ID AS CHAT
  final deviceId = currentDeviceId;
  // if (deviceId == null || deviceId.isEmpty) {
  //   throw Exception('❌ DeviceId missing at auth');
  // }

  // 🔑 FORCE REGISTER IDENTITY KEY
  final identity = IdentityKeyManager(firestore: firestore);
  await identity.loadOrCreateIdentityKey(uid, deviceId);

  // 🔍 VERIFY DEVICE EXISTS (CRITICAL)
  final snap = await firestore.collection('userKeys').doc(uid).get();
  if (!snap.exists || snap.data()?['devices']?[deviceId] == null) {
  throw Exception('❌ Device key registration failed');
}
  final devices = snap.data()?['devices'] as Map<String, dynamic>?;

  if (devices == null || !devices.containsKey(deviceId)) {
    throw Exception('❌ Device key not written to Firestore');
  }

  await PrefHelper.isLoginSuccess(isLoggedIn: true);

  final userDoc = await firestore.collection('users').doc(uid).get();
  final data = userDoc.data();

  if (userDoc.exists && data?['profileCompleted'] == true) {
    Get.offAllNamed('/home');
  } else {
    Get.offAllNamed(
      '/user-information',
      arguments: {'phoneNumber': data?['phoneNumber'] ?? ''},
    );
  }
}



  // ---------------- Profile update / save ----------------

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String about,
    File? profilePic,
    required WidgetRef ref,
    required BuildContext context,
  }) async {
    try {
      String? photoUrl;

      if (profilePic != null) {
        photoUrl = await ref
            .read(commonFirebaseStorageRepositoryProvider)
            .uploadProfilePicture(uid, profilePic);
      }

      final updateData = <String, dynamic>{
        "name": name,
        "about": about,
      };
      if (photoUrl != null) updateData["profilePic"] = photoUrl;

      await firestore.collection("users").doc(uid).update(updateData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully")),
        );
      }
    } catch (e) {
      debugPrint("updateUserProfile error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update profile")),
        );
      }
    }
  }

  Future<void> saveUserDataToFirebase({
  required String uid,
  required String name,
  required String about,
  required String phoneNumber,
  required String profilePicUrl,
  required BuildContext context,
}) async {
  controller.isUserUpdate.value = true;

  try {
    final user = UserModel(
      uid: uid,
      name: name,
      profilePic: profilePicUrl,
      phoneNumber: phoneNumber,
      about: about,
      isOnline: true,
    );

    await firestore.collection('users').doc(uid).set({
  ...user.toMap(),
  'profileCompleted': true,
}, SetOptions(merge: true));

    await PrefHelper.setUserInfoComplete();
    LocalStorage.saveMyUid(uid);

    Get.offAllNamed(HomeScreen.routeName);
  } catch (e) {
    debugPrint("saveUserDataToFirebase error: $e");
    _showSnack(context, "Failed to save profile");
  } finally {
    controller.isUserUpdate.value = false;
  }
}
  // ---------------- Logout / Delete account ----------------
Future<void> logout() async {
  await auth.signOut();

  // 🔥 CLEAR E2E STATE
  await resetE2EIfNeeded();

  await PrefHelper.logout();
  LocalStorage.clearAll();

  Get.offAll(() => const LoginScreen());
}

Future<void> deleteAccount(BuildContext context) async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;

  final user = auth.currentUser;
  if (user == null) return;

  try {
    final uid = user.uid;

    // ==========================
    // 1️⃣ DELETE FIRESTORE DATA
    // ==========================
    await resetE2EIfNeeded();
    await PrefHelper.logout();
    LocalStorage.clearAll();
    final batch = firestore.batch();

    // users collection
    batch.delete(firestore.collection('users').doc(uid));

    // device tokens
    batch.delete(firestore.collection('deviceTokens').doc(uid));

    // E2E keys
    batch.delete(firestore.collection('userKeys').doc(uid));

    // blocked users subcollection
    final blockedSnap = await firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .get();

    for (final d in blockedSnap.docs) {
      batch.delete(d.reference);
    }

    await batch.commit();

    // ==========================
    // 2️⃣ DELETE CHAT DATA
    // ==========================

    final chatSnap = await firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .get();

    for (final chat in chatSnap.docs) {
      final messages = await chat.reference.collection('messages').get();
      for (final m in messages.docs) {
        await m.reference.delete();
      }
      await chat.reference.delete();
    }

    // ==========================
    // 3️⃣ DELETE FIREBASE STORAGE
    // ==========================

    Future<void> deleteFolder(String path) async {
      final ref = storage.ref(path);
      final list = await ref.listAll();

      for (final file in list.items) {
        await file.delete();
      }
      for (final folder in list.prefixes) {
        await deleteFolder(folder.fullPath);
      }
    }

    await Future.wait([
      deleteFolder('profilePics/$uid'),
      deleteFolder('chatMedia/$uid'),
      deleteFolder('status/$uid'),
    ]);

    // ==========================
    // 4️⃣ DELETE AUTH ACCOUNT
    // ==========================

    await user.delete();

    // ==========================
    // 5️⃣ LOCAL CLEANUP
    // ==========================

    await PrefHelper.logout();
    LocalStorage.clearAll();

    Get.offAll(() => const LoginScreen());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deleted permanently')),
    );

  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please re-login and try again'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Auth error')),
      );
    }
  } catch (e) {
    debugPrint('❌ DELETE ACCOUNT FAILED: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}


}
