// lib/views/settings/profile_screen.dart

import 'dart:io';

import 'package:adchat/widget/safe_image.dart';
import 'package:adchat/utils/assets.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import 'package:adchat/controller/settings/about_screen_controller.dart';
import 'package:adchat/controller/settings/settings_screen_controller.dart';
import 'package:adchat/utils/custom_color.dart';
import 'package:adchat/utils/dimensions.dart';
import 'package:adchat/utils/strings.dart';
import 'package:adchat/views/settings/about_screen.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:adchat/controller/image_picker_controller.dart';
import 'package:adchat/widget/picker/picker_widget.dart';
import 'package:adchat/controller/storage/common_firebase_storage_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final controller = Get.put(SettingsScreenController());
  final imageController = Get.put(ImagePickerController());
  final aboutScreenController = Get.put(AboutScreenController());

  File? image;
  String phoneNumber = "";
  String profileUrl = "";

  // -------------------------
  // Load user number initially
  // -------------------------
  @override
  void initState() {
    super.initState();
    phoneNumber = controller.userNumber.value; // From GetX controller
    profileUrl = controller.userImage.value;  // Old image URL
  }

  // -------------------------
  // IMAGE PICKERS
  // -------------------------
  void pickFromGallery() async {
    final picked = await pickImageFromGallery(context);
    if (picked != null) {
      image = picked;
      setState(() {});
    }
  }

  void pickFromCamera() async {
    final picked = await pickImageFromCamera(context);
    if (picked != null) {
      image = picked;
      setState(() {});
    }
  }

  // -------------------------
  // SAVE USER PROFILE
  // -------------------------
  Future<void> storeUserData() async {
    final name = controller.userNameController.text.trim();
    final about = aboutScreenController.userAbout.value;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name cannot be empty")),
      );
      return;
    }

    // Upload new profile pic if selected
    String finalUrl = profileUrl;

    if (image != null) {
      finalUrl = await ref
          .read(commonFirebaseStorageRepositoryProvider)
          .uploadProfilePicture(uid, image!);
    }

    await ref.read(authRepositoryProvider).updateUserProfile(
          uid: uid,
          name: name,
          about: about,
          profilePic: image,   // File
          ref: ref,
          context: context,
        );

    // Update UI instantly
    controller.userImage.value = finalUrl;

    Get.back();
  }

  // -------------------------
  // UI BUILD
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.profile.tr)),
      body: _bodyWidget(),
    );
  }

  Widget _bodyWidget() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 20),
          _profileImageWidget(),
          SizedBox(height: 30),
          _profileInfoWidget(),
        ],
      ),
    );
  }

  // -------------------------
  // PROFILE IMAGE
  // -------------------------
  Widget _profileImageWidget() {
    return Obx(() {
      return Stack(
        alignment: Alignment.centerRight,
        children: [
          image != null
              ? CircleAvatar(
                  radius: Dimensions.radius * 7.5,
                  backgroundImage: FileImage(image!),
                )
              : SafeImage(
                  url: controller.userImage.value,
                  size: Dimensions.heightSize * 14,
                ),

          // Camera Button
          Positioned(
            bottom: 10,
            right: 10,
            child: CircleAvatar(
              radius: Dimensions.radius * 1.8,
              backgroundColor: CustomColor.primaryColor,
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor:
                        Get.isDarkMode ? Colors.black : Colors.white,
                    builder: (c) => imagePickerBottomSheetWidget(c),
                  );
                },
                child: Icon(Icons.photo_camera_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      );
    });
  }

  // -------------------------
  // PROFILE INFO
  // -------------------------
  Widget _profileInfoWidget() {
    return Obx(() {
      final aboutText = aboutScreenController.userAbout.value.isNotEmpty
          ? aboutScreenController.userAbout.value
          : "Hey there! I am using AdChat.";

      final nameText = controller.userNameController.text.isNotEmpty
          ? controller.userNameController.text
          : Strings.nameHint;

      return Column(
        children: [
          _infoTile(
            icon: Icons.person,
            title: Strings.name,
            value: nameText,
            onTap: () => _editName(),
          ),
          Divider(),
          _infoTile(
            icon: Icons.info_outline_rounded,
            title: Strings.about,
            value: aboutText,
            onTap: () => Get.to(AboutScreen()),
          ),
          Divider(),
          _infoTile(
            icon: Icons.phone_rounded,
            title: Strings.phone,
            value: phoneNumber,
            hideEdit: true,
            onTap: () {},
          ),
        ],
      );
    });
  }

  // TILE UI
  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    bool hideEdit = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      subtitle: Text(value),
      trailing:
          hideEdit ? null : Icon(Icons.edit, color: CustomColor.primaryColor),
    );
  }

  // -------------------------
  // NAME EDIT POPUP
  // -------------------------
  void _editName() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Get.isDarkMode ? Colors.black : Colors.white,
      isScrollControlled: true,
      builder: (_) => _nameEditor(),
    );
  }

  Widget _nameEditor() {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.all(16),
        height: 180,
        child: Column(
          children: [
            Text("Enter your name"),
            TextField(controller: controller.userNameController),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () => storeUserData(),
                child: Text("SAVE"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------
  // IMAGE PICKER BOTTOM SHEET
  // -------------------------
  Widget imagePickerBottomSheetWidget(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.camera_alt_rounded,
                    color: CustomColor.primaryColor),
                onPressed: () => {pickFromCamera(), Get.back()},
              ),
              Text("Camera"),
            ],
          ),
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.photo, color: CustomColor.primaryColor),
                onPressed: () => {pickFromGallery(), Get.back()},
              ),
              Text("Gallery"),
            ],
          ),
        ],
      ),
    );
  }
}
