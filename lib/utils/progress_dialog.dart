import 'package:adchat/utils/custom_color.dart';
import 'package:adchat/utils/dimensions.dart';
import 'package:adchat/utils/size.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProgressDialog {
  static bool isProgressVisible = false;

  static void showProgressDialog({
    isCancellable = false,
    required String loadingText,
  }) async {
    if (!isProgressVisible) {
      Get.dialog(
        Dialog(
          child: Container(
            padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.8),
            child: Row(
              children: [
                const CircularProgressIndicator.adaptive(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CustomColor.primaryColor,
                  ),
                ),
                horizontalSpace(Dimensions.widthSize * 1.5),
                Text(loadingText)
              ],
            ),
          ),
        ),
        barrierDismissible: isCancellable,
      );
      isProgressVisible = true;
    }
  }

  static void hideProgressDialog() {
    if (isProgressVisible) Get.back();
    isProgressVisible = false;
  }
}
