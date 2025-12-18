import '../../utils/size.dart';
import '../../utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../widget/others/lable_widget.dart';

class Chats extends StatelessWidget {
  const Chats({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Strings.chats.tr,
        ),
      ),
      body: _bodyWidget(context),
    );
  }

  _bodyWidget(BuildContext context) {
    return ListView(
      children: [
        _displayWidget(context),
      ],
    );
  }

  _displayWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: crossStart,
      children: [
        labelWidget(Strings.display.tr),
        _customListWidget(
          icon: Icons.brightness_medium,
          title: Strings.theme.tr,
          subTitle: Get.isDarkMode ? Strings.dark.tr : Strings.light.tr,
          goTo: () {
            Themes().switchTheme();
            Get.back();
          },
        ),
      ],
    );
  }

  _customListWidget({
    required IconData icon,
    required String title,
    String? subTitle,
    required VoidCallback goTo,
  }) {
    return ListTile(
      onTap: goTo,
      minLeadingWidth: Dimensions.widthSize * 3,
      dense: false,
      leading: Padding(
        padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.27),
        child: Icon(
          icon,
          color: CustomColor.greyColor,
        ),
      ),
      title: Text(title),
      subtitle: subTitle == ''
          ? null
          : Text(
              subTitle!,
              style: CustomStyle.smallTextStyle,
            ),
    );
  }
}
