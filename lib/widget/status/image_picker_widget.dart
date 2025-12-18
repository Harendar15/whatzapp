// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:adchat/views/status/confirm_status_screen.dart';
import 'package:adchat/widget/picker/picker_widget.dart';
import '../../../../utils/custom_color.dart';
import '../../../../utils/dimensions.dart';

Widget imagePickerBottomSheetWidget(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Wrap(
      alignment: WrapAlignment.center,
      children: [
        _iconBtn(
          icon: Icons.image,
          label: "Gallery",
          onTap: () async {
            Get.back();
            File? file = await pickImageFromGallery(context);
            if (file != null) {
              Get.to(() => ConfirmStatusScreen(file: file));
            }
          },
        ),
        _iconBtn(
          icon: Icons.camera_alt,
          label: "Camera",
          onTap: () async {
            Get.back();
            File? file = await pickImageFromCamera(context);
            if (file != null) {
              Get.to(() => ConfirmStatusScreen(file: file));
            }
          },
        ),
        _iconBtn(
          icon: Icons.video_library,
          label: "Video",
          onTap: () async {
            Get.back();
            File? file = await pickVideoFromGallery(context);
            if (file != null) {
              Get.to(() => ConfirmStatusScreen(file: file));
            }
          },
        ),
        _iconBtn(
          icon: Icons.videocam,
          label: "Record",
          onTap: () async {
            Get.back();
            File? file = await pickVideoFromCamera(context);
            if (file != null) {
              Get.to(() => ConfirmStatusScreen(file: file));
            }
          },
        ),
      ],
    ),
  );
}

Widget _iconBtn({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 40, color: CustomColor.primaryColor),
        ),
        Text(label),
      ],
    ),
  );
}
