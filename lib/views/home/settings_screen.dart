import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:adchat/utils/custom_color.dart';
import 'package:adchat/utils/custom_style.dart';
import 'package:adchat/utils/dimensions.dart';
import 'package:adchat/utils/size.dart';
import 'package:adchat/utils/strings.dart';

import '../../controller/settings/settings_screen_controller.dart';
import '../../controller/settings/about_screen_controller.dart';

import 'package:adchat/views/settings/account_screen.dart';
import 'package:adchat/views/settings/chats.dart';
import 'package:adchat/widget/safe_image.dart';

class SettingsScreen extends StatelessWidget {
  static const routeName = '/settings';

  SettingsScreen({super.key});

  final controller = Get.put(SettingsScreenController());
  final aboutController = Get.put(AboutScreenController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.settings.tr),
      ),
      body: _bodyWidget(),
    );
  }

  Widget _bodyWidget() {
    return ListView(
      children: [
        verticalSpace(Dimensions.heightSize * 0.6),
        _profileWidget(),
        _listOptions(),
      ],
    );
  }

  Widget _profileWidget() {
  return Obx(() {
    final image = controller.userImage.value;
    final name = controller.userName.value;
    final about = aboutController.userAbout.value;

    return ListTile(
      onTap: controller.goToProfileScreen,
      leading: SafeImage(
        url: image,
        size: Dimensions.radius * 6,
      ),
      title: Text(
        name.isEmpty ? 'Unknown User' : name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        about.isNotEmpty ? about : Strings.aboutMeDefault,
        style: CustomStyle.smallTextStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  });
}


  Widget _listOptions() {
    return Column(
      children: [
        const Divider(),
        _item(
          icon: Icons.key,
          title: Strings.account.tr,
          subTitle: Strings.accountSubTitle.tr,
          rotate: true,
          goTo: () => Get.to(AccountScreen()),
        ),
        _item(
          icon: Icons.chat_rounded,
          title: Strings.chats.tr,
          subTitle: Strings.chatsSubTitle.tr,
          goTo: () => Get.to(const Chats()),
        ),
      ],
    );
  }

  Widget _item({
    required IconData icon,
    required String title,
    String? subTitle,
    bool rotate = false,
    required VoidCallback goTo,
  }) {
    return ListTile(
      onTap: goTo,
      minLeadingWidth: Dimensions.widthSize * 3,
      leading: Padding(
        padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.27),
        child: Transform.rotate(
          angle: rotate ? math.pi / 1.7 : 0,
          child: Icon(icon, color: CustomColor.greyColor),
        ),
      ),
      title: Text(title),
      subtitle: (subTitle != null && subTitle.isNotEmpty)
          ? Text(subTitle, style: CustomStyle.smallTextStyle)
          : null,
    );
  }
}
