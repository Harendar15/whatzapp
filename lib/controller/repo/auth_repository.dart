// lib/controller/repo/auth_repository.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import 'package:adchat/views/home/home_screen.dart';
import '../../models/user_model.dart';
import '../../helpers/prefs_services.dart';
import '../auth/login_controller.dart';
import '../storage/common_firebase_storage_repository.dart';
import '../../views/auth/otp_screen.dart';
import '../../helpers/local_storage.dart';
import '../../crypto/identity_key_manager.dart';



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

  /// Device id - prefer one from LocalStorage if present, otherwise a safe fallback.
String get currentDeviceId {
  final uid = auth.currentUser?.uid;
  return uid != null ? "primary_$uid" : "unknown_device";
}

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
          Get.toNamed(OTPScreen.routeName, arguments: {
            "verificationId": verificationId,
            "phoneNumber": phoneNumber,
            "resendToken": resendToken,
          });
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
          controller.isLoading.value = false;
          _resendToken = resendToken;
          Get.offNamed(OTPScreen.routeName, arguments: {
            "verificationId": verificationId,
            "phoneNumber": phoneNumber,
            "resendToken": resendToken,
          });
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
      if (otp.trim().isEmpty) {
        _showSnack(context, "Enter OTP");
        return;
      }

      if (verificationId.isEmpty) {
        _showSnack(context, "Verification ID missing. Resend OTP.");
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

     final userCredential = await auth.signInWithCredential(credential);

       final uid = userCredential.user!.uid;
      final phone = userCredential.user!.phoneNumber ?? phoneNumber;

      // 🔥 VERY IMPORTANT FIX
      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'phoneNumber': phone,
        'isOnline': true,
      }, SetOptions(merge: true));

      await _routeAfterSignIn();
 
    } on FirebaseAuthException catch (e) {
      debugPrint("verifyOTP firebase error: ${e.code} ${e.message}");
      _showSnack(context, e.message ?? "OTP verification failed");
    } catch (e) {
      debugPrint("verifyOTP error: $e");
      _showSnack(context, "OTP verification failed");
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

  // ---------------- Post sign-in routing ----------------
  Future<void> _routeAfterSignIn() async {
  final uid = auth.currentUser?.uid;
  if (uid == null) return;

  // save uid
  LocalStorage.saveMyUid(uid);

  // 🔑 Ensure identity key
  final identity = IdentityKeyManager(firestore: firestore);
  final deviceId = currentDeviceId;
  await identity.loadOrCreateIdentityKey(uid, deviceId);

  await PrefHelper.isLoginSuccess(isLoggedIn: true);

  final doc =
      await firestore.collection('users').doc(uid).get();

  if (!doc.exists) {
    // 🔥 very rare case
    Get.offAllNamed('/user-information');
    return;
  }

final data = doc.data();

if (doc.exists && data?['profileCompleted'] == true) {
  Get.offAllNamed('/home');
} else {
  Get.offAllNamed('/user-information');
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

}
