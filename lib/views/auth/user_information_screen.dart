// lib/views/auth/user_information_screen.dart
// ignore_for_file: prefer_const_constructors

import 'dart:io';
import '/controller/auth/login_controller.dart';
import '/controller/settings/about_screen_controller.dart';
import '/utils/custom_color.dart';
import '/utils/dimensions.dart';
import '/utils/strings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import '../../helpers/prefs_services.dart';
import '../../utils/size.dart';
import 'package:adchat/helpers/image_compress.dart';

import 'package:adchat/views/home/home_screen.dart';
import 'package:adchat/widget/custom_button.dart';
import 'package:adchat/widget/custom_loader.dart';
import 'package:adchat/widget/picker/picker_widget.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:adchat/controller/storage/common_firebase_storage_repository.dart';

class UserInformationScreen extends ConsumerStatefulWidget {
  static const String routeName = '/user-information';

  const UserInformationScreen({super.key});

  @override
  ConsumerState<UserInformationScreen> createState() =>
      _UserInformationScreenState();
}

class _UserInformationScreenState
    extends ConsumerState<UserInformationScreen> {
  final TextEditingController nameController = TextEditingController();
  final aboutScreenController = Get.put(AboutScreenController());
  final controller = Get.find<LoginController>();


  File? image;
  String phoneNumber = '';

  @override
  void initState() {
    super.initState();
    final args = Get.arguments ?? {};
    phoneNumber = args['phoneNumber'] ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // ---------------- IMAGE PICK FUNCTIONS ----------------

  Future pickFromGallery() async {
  File? img = await pickImageFromGallery(context);
  if (img != null) {
    final compressed = await ImageCompressor.compress(img);
    if (!mounted) return;
    setState(() => image = compressed);
  }
}


  Future pickFromCamera() async {
  File? img = await pickImageFromCamera(context);
  if (img != null) {
    final compressed = await ImageCompressor.compress(img);
    if (!mounted) return;
    setState(() => image = compressed);
  }
}


  // ---------------- SAVE USER DATA ---------------------

  void storeUserData() async {
  if (!mounted) return;

  String name = nameController.text.trim();
  String about = aboutScreenController.userAbout.value;

  if (name.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Please enter your name")),
    );
    return;
  }

  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    String profileUrl = "https://i.ibb.co/2M4d1j6/user.png";

    if (image != null) {
      profileUrl = await ref.read(commonFirebaseStorageRepositoryProvider)
          .storeFileToFirebase(
        "profilePics/$uid/profile.jpg",
        image!,
      );
    }

    if (!mounted) return;

    await ref.read(authRepositoryProvider).saveUserDataToFirebase(
      uid: uid,
      name: name,
      about: about,
      phoneNumber: phoneNumber,
      profilePicUrl: profileUrl,
      context: context,
    );

    await PrefHelper.setUserInfoComplete();

    if (!mounted) return;
    Get.offAllNamed(HomeScreen.routeName);

  } catch (e) {
    debugPrint("storeUserData error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to save user data")));
    }
  }
}



  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: _appBarWidget(context),
        body: Obx(
          () => controller.isUserUpdate.isTrue
              ? const CustomLoader()
              : _bodyWidget(context),
        ),
        bottomSheet: Obx(
          () => controller.isUserUpdate.isTrue
              ? const CustomLoader()
              : _buttonWidget(context),
        ),
      ),
    );
  }

  // ---------------- UI SECTION --------------------------

  Widget _bodyWidget(BuildContext context) {
    return Center(
      child: Column(
        children: [
          _hintTextWidget(context),
          _profileImageWidget(context),
          _inputFieldWidget(context),
        ],
      ),
    );
  }

  Widget _profileImageWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: Dimensions.marginSize),
      child: Stack(
        children: [
          image == null
              ? InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      backgroundColor: Get.isDarkMode
                          ? Theme.of(context).appBarTheme.backgroundColor
                          : Colors.white,
                      context: context,
                      builder: (BuildContext context) =>
                          imagePickerBottomSheetWidget(context),
                    );
                  },
                  child: CircleAvatar(
                    radius: Dimensions.radius * 6.5,
                    backgroundColor:
                        CustomColor.greyColor.withOpacity(0.6),
                    child: Icon(
                      Icons.add_a_photo_rounded,
                      color: CustomColor.greyColor,
                      size: Dimensions.iconSizeLarge * 2.1,
                    ),
                  ),
                )
              : CircleAvatar(
                radius: Dimensions.radius * 7,
                backgroundColor: Colors.grey.shade300,
                child: ClipOval(
                  child: Image.file(
                    image!,
                    width: Dimensions.radius * 14,
                    height: Dimensions.radius * 14,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Icon(Icons.person, size: 40);
                    },
                  ),
                ),
),

        ],
      ),
    );
  }

  Widget _inputFieldWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Dimensions.marginSize),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: Strings.enterYourName.tr,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: CustomColor.primaryColor),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) =>
                    _emojiPickerWidget(context),
              );
            },
            icon: const Icon(Icons.emoji_emotions_outlined),
          )
        ],
      ),
    );
  }

  // ----------------- BOTTOM SHEET PICKER ----------------

  Widget imagePickerBottomSheetWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(Dimensions.marginSize * 0.5),
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: mainSpaceBet,
            children: [
              Text(Strings.profilePhoto.tr),
              GestureDetector(
                onTap: () => Get.back(),
                child: const Icon(Icons.close),
              ),
            ],
          ),
          Row(
            children: [
              Column(
                children: [
                  _pickerIcon(
                    Icons.camera_alt,
                    () async {
                      await pickFromCamera();
                      Get.back();
                    },
                  ),
                  verticalSpace(8),
                  Text(Strings.camera.tr),
                ],
              ),
              horizontalSpace(40),
              Column(
                children: [
                  _pickerIcon(
                    Icons.photo,
                    () async {
                      await pickFromGallery();
                      Get.back();
                    },
                  ),
                  verticalSpace(8),
                  Text(Strings.gallery.tr),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pickerIcon(IconData icon, VoidCallback onTap) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: CustomColor.borderColor),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: CustomColor.primaryColor,
          size: Dimensions.iconSizeDefault,
        ),
      ),
    );
  }

  Widget _buttonWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Dimensions.marginSize * 4,
        vertical: Dimensions.marginSize * 0.8,
      ),
      child: CustomButton(
        onPressed: storeUserData,
        text: Strings.next,
      ),
    );
  }

  Widget _hintTextWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: Dimensions.marginSize),
      child: Text(
        Strings.pleaseProvide.tr,
        style: TextStyle(
          fontSize: Dimensions.smallestTextSize * 1.1,
          color: Get.isDarkMode
              ? CustomColor.white.withOpacity(0.6)
              : CustomColor.black.withOpacity(0.6),
        ),
      ),
    );
  }

  AppBar _appBarWidget(BuildContext context) => AppBar(
        elevation: 0,
        backgroundColor: Get.isDarkMode
            ? Theme.of(context).appBarTheme.backgroundColor
            : Colors.white,
        title: Text(
          Strings.profileInfo.tr,
          style: TextStyle(color: CustomColor.primaryColor),
        ),
        centerTitle: true,
      );

  Widget _emojiPickerWidget(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.34,
      child: EmojiPicker(
        onEmojiSelected: (c, e) {
          nameController.text += e.emoji;
        },
      ),
    );
  }
}

// Email regex helper
extension EmailValidator on String {
  bool isValidEmail() {
    return RegExp(
            r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$')
        .hasMatch(this);
  }
}
