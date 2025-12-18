// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:adchat/controller/image_picker_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import '../storage/common_firebase_storage_repository.dart';
import '../../views/settings/profile_screen.dart';

class SettingsScreenController extends GetxController {
  final userNameController = TextEditingController();
  final userAboutController = TextEditingController();

  final imageController = Get.put(ImagePickerController());

  RxString userName = ''.obs;
  RxString userImage = ''.obs;
  RxString userNumber = ''.obs;
  RxBool isHideChat = false.obs;

  RxBool isEmojiContainer = false.obs;

  final User? user = FirebaseAuth.instance.currentUser;

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    getUserData();
    super.onInit();
  }

  /// ------------------------- GET USER DATA -------------------------
  Future<void> getUserData() async {
    _isLoading.value = true;

    if (user == null) {
      _isLoading.value = false;
      debugPrint("⚠ No Firebase user found while reading settings.");
      return;
    }

    try {
      String uid = user!.uid;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        _isLoading.value = false;
        return;
      }

      final data = doc.data()!;

      userImage.value = data['profilePic'] ?? '';
      userName.value = data['name'] ?? '';
      userNumber.value = data['phoneNumber'] ?? '';

      userNameController.text = userName.value;

      debugPrint("🔹 User settings loaded successfully");

    } catch (e) {
      debugPrint("❌ getUserData error: $e");
    } finally {
      _isLoading.value = false;
    }
  }

  /// ------------------------- UPDATE NAME -------------------------
  Future<void> updateUserData() async {
    if (user == null) return;

    String uid = user!.uid;
    String newName = userNameController.text.trim();

    if (newName.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': newName,
      });

      userName.value = newName;

      debugPrint("✔ Username updated");

    } catch (e) {
      debugPrint("❌ updateUserData error: $e");
    }
  }

  /// ------------------------- UPDATE PROFILE PICTURE -------------------------
  Future<void> updateProfilePic({required WidgetRef ref}) async {
    if (user == null) return;

    if (imageController.imagePath.value.isEmpty) {
      debugPrint("⚠ No image selected");
      return;
    }

    String uid = user!.uid;

    try {
      final file = File(imageController.imagePath.value);

      final photoUrl = await ref
          .read(commonFirebaseStorageRepositoryProvider)
          .storeFileToFirebase(
            'profilePic/$uid',
            file,
          );

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profilePic': photoUrl,
      });

      userImage.value = photoUrl;

      debugPrint("✔ Profile picture updated");

    } catch (e) {
      debugPrint("❌ updateProfilePic error: $e");
    } finally {
      imageController.imagePath.value = '';
      if (Get.isOverlaysOpen) Get.back();
      getUserData();
    }
  }

  /// ------------------------- NAVIGATION -------------------------
  void goToProfileScreen() {
    Get.to(() => const ProfileScreen());
  }
}
