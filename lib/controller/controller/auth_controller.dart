// lib/controller/auth/auth_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repo/auth_repository.dart';
import 'package:adchat/models/user_model.dart';
import '../storage/common_firebase_storage_repository.dart';

final authControllerProvider =
    Provider<AuthController>((ref) => AuthController(ref));

class AuthController {
  final ProviderRef ref;
  AuthController(this.ref);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  // -----------------------------
  // SEND OTP
  // -----------------------------
  Future<void> sendOtp({
    required BuildContext context,
    required String phone,
  }) async {
    await _repo.signInWithPhone(context, phone);
  }

  // -----------------------------
  // RESEND OTP
  // -----------------------------
  Future<void> resendOtp({
    required BuildContext context,
    required String phone,
  }) async {
    await _repo.resendOtp(context: context, phoneNumber: phone);
  }

  // -----------------------------
  // VERIFY OTP
  // -----------------------------
  Future<void> verifyOtp({
    required BuildContext context,
    required String otp,
    required String verificationId,
    required String phoneNumber,
  }) async {
    await _repo.verifyOTP(
      context: context,
      otp: otp,
      verificationId: verificationId,
      phoneNumber: phoneNumber,
    );
  }

  // -----------------------------
  // SAVE USER DATA AFTER SIGNUP
  // (with image upload)
  // -----------------------------
  Future<void> saveUserProfile({
    required BuildContext context,
    required String name,
    required String about,
    required String phone,
    File? imageFile,
  }) async {
    final uid = _repo.currentUid;
    if (uid == null) {
      Get.snackbar("Error", "Login session expired. Try again.");
      return;
    }

    // DEFAULT PIC
    String photoUrl = "https://i.ibb.co/2M4d1j6/user.png";

    // If user selected an image → upload it
    if (imageFile != null) {
      final uploadService =
          ref.read(commonFirebaseStorageRepositoryProvider);

      photoUrl = await uploadService.storeFileToFirebase(
        "profilePics/$uid/profile.jpg",
        imageFile,
      );
    }

    // Send final data to Repository
    await _repo.saveUserDataToFirebase(
      uid: uid,
      name: name,
      about: about,
      phoneNumber: phone,
      profilePicUrl: photoUrl,
      context: context,
    );
  }

  // -----------------------------
  // UPDATE USER PROFILE (Edit Profile Screen)
  // -----------------------------
  Future<void> updateProfile({
    required BuildContext context,
    required String name,
    required String about,
    File? newImage,
  }) async {
    final uid = _repo.currentUid!;
    String? uploadedUrl;

    if (newImage != null) {
      final uploadService =
          ref.read(commonFirebaseStorageRepositoryProvider);

      uploadedUrl = await uploadService.storeFileToFirebase(
        "profilePics/$uid/profile.jpg",
        newImage,
      );
    }

    await _repo.updateUserProfile(
      uid: uid,
      name: name,
      about: about,
      profilePic: null, // not needed here
      ref: ref as WidgetRef, // only if needed in your original repo
      context: context,
    );
  }

  // -----------------------------
  // GET CURRENT USER STREAM
  // -----------------------------
  Stream<UserModel> userData(String uid) {
    return _repo.userData(uid);
  }

  // -----------------------------
  // GET ALL USERS STREAM
  // -----------------------------
  Stream<List<UserModel>> allUsers() {
    return _repo.allUsers();
  }
}
