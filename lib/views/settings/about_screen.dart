import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/models/about_model.dart';
import '/utils/dimensions.dart';
import '/utils/size.dart';
import '/utils/strings.dart';
import '../../widget/others/lable_widget.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings/about_screen_controller.dart';
import '../../utils/custom_color.dart';
import '../../widget/inputs/input_filed_widget.dart';

class AboutScreen extends StatelessWidget {
  AboutScreen({super.key});

  final controller = Get.put(AboutScreenController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.about.tr),
      ),
      body: _bodyWidget(context),
    );
  }

  Widget _bodyWidget(BuildContext context) {
    return Obx(() {
      return Column(
        children: [
          verticalSpace(Dimensions.heightSize * 0.6),
          _currentlySetToWidget(context),
          _aboutListWidget(context),
        ],
      );
    });
  }

  Widget _currentlySetToWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: crossStart,
      mainAxisSize: mainMin,
      children: [
        labelWidget(Strings.currentlySetTo.tr),
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Get.isDarkMode
                  ? Theme.of(context).appBarTheme.backgroundColor
                  : Colors.white,
              builder: (context) => showInputFieldWidget(context),
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: Dimensions.marginSize,
              vertical: Dimensions.marginSize * 0.5,
            ),
            child: Row(
              mainAxisAlignment: mainSpaceBet,
              children: [
                Expanded(
                  child: Text(
                    controller.userAbout.value.isNotEmpty
                        ? controller.userAbout.value
                        : "Hey there! I'm using AdChat.",
                    maxLines: 5,
                  ),
                ),
                Icon(
                  Icons.edit_rounded,
                  size: Dimensions.iconSizeSmall * 1.4,
                  color: CustomColor.primaryColor,
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        labelWidget(Strings.selectAbout),
      ],
    );
  }

  Widget _aboutListWidget(BuildContext context) {
    return Flexible(
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: Dimensions.marginSize,
          vertical: Dimensions.marginSize * 0.5,
        ),
        child: ListView(
          children: List.generate(
            aboutTypeList.length,
            (i) => InkWell(
              onTap: () {
                final newAbout = aboutTypeList[i];
                controller.userAbout.value = newAbout;
                controller.userAboutController.text = newAbout;
                controller.updateUserAbout();
              },
              child: Container(
                margin: EdgeInsets.symmetric(
                  vertical: Dimensions.marginSize * 0.7,
                ),
                child: Row(
                  mainAxisAlignment: mainSpaceBet,
                  children: [
                    Text(aboutTypeList[i]),
                    Visibility(
                      visible: aboutTypeList[i] == controller.userAbout.value,
                      child: const Icon(
                        Icons.check_rounded,
                        color: CustomColor.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget showInputFieldWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: EdgeInsets.all(Dimensions.marginSize * 0.5),
        width: 300.w,
        height: 160.h,
        child: Column(
          crossAxisAlignment: crossStart,
          children: [
            const Text("Edit About"),
            inputFieldWidget(
              context,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => _emojiPickerWidget(context),
                );
              },
              name: controller.userAboutController,
            ),
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: Dimensions.marginSize * 0.6,
                vertical: Dimensions.marginSize * 0.8,
              ),
              child: Row(
                mainAxisAlignment: mainEnd,
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Text(
                      Strings.cancel.tr,
                      style: TextStyle(color: CustomColor.primaryColor),
                    ),
                  ),
                  horizontalSpace(Dimensions.widthSize * 5),
                  GestureDetector(
                    onTap: () {
                      final text = controller.userAboutController.text.trim();
                      if (text.isNotEmpty) {
                        controller.userAbout.value = text;
                        controller.updateUserAbout();
                      }
                      Get.back();
                    },
                    child: Text(
                      Strings.save.tr,
                      style: TextStyle(color: CustomColor.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiPickerWidget(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.34,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            controller.userAboutController.text += emoji.emoji;
          },
        ),
      ),
    );
  }
}
