// lib/widget/picker/image_picker_bottom_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../views/status/confirm_status_screen.dart';
import '../../widget/picker/picker_widget.dart';
import '../../utils/custom_color.dart';
import '../../utils/dimensions.dart';

Widget imagePickerBottomSheetWidget(BuildContext context) {
  return SizedBox(
    width: 270,
    height: MediaQuery.of(context).size.height * 0.15,
    child: Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
              child: IconButton(
                onPressed: () async {
                  Get.back();
                  File? pickedImage = await pickImageFromGallery(context);
                  if (pickedImage != null) {
                    Get.to(() => ConfirmStatusScreen(file: pickedImage));
                  }
                },
                icon: const Icon(
                  Icons.image,
                  color: CustomColor.primaryColor,
                  size: 50,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
              child: IconButton(
                onPressed: () async {
                  Get.back();
                  File? pickedImage = await pickImageFromCamera(context);
                  if (pickedImage != null) {
                    Get.to(() => ConfirmStatusScreen(file: pickedImage));
                  }
                },
                icon: const Icon(
                  Icons.camera_alt,
                  color: CustomColor.primaryColor,
                  size: 50,
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            onPressed: () {
              Get.back();
            },
            icon: const Icon(
              Icons.close,
              color: Colors.red,
            ),
          ),
        ),
      ],
    ),
  );
}
