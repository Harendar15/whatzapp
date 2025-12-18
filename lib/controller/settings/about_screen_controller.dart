import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AboutScreenController extends GetxController {
  RxString userAbout = 'Hey there! I am using AdChat.'.obs;
  final userAboutController = TextEditingController();

  final User? user = FirebaseAuth.instance.currentUser;

  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    getUserData();
    super.onInit();
  }

  /// --------------------- GET USER ABOUT ----------------------
  Future<void> getUserData() async {
    _isLoading.value = true;

    if (user == null) {
      _isLoading.value = false;
      debugPrint("⚠ No Firebase user found while loading About");
      return;
    }

    try {
      String uid = user!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        String aboutValue = doc.data()!['about'] ?? '';
        userAbout.value = aboutValue;
        userAboutController.text = aboutValue;
      }
    } catch (e) {
      debugPrint("❌ getUserData error: $e");
    } finally {
      _isLoading.value = false;
    }
  }

  /// --------------------- UPDATE USER ABOUT ----------------------
  Future<void> updateUserAbout() async {
    if (user == null) {
      debugPrint("⚠ Can't update about: user is null");
      return;
    }

    String uid = user!.uid;
    String aboutText = userAboutController.text.trim();

    try {
      if (aboutText.isEmpty) {
        aboutText = "Hey there! I am using AdChat.";
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'about': aboutText});

      userAbout.value = aboutText;
      debugPrint("✔ About updated successfully");

    } catch (e) {
      debugPrint("❌ updateUserAbout error: $e");
    }
  }
}
