// lib/widget/chat/icon_creation_widget.dart
import 'package:adchat/utils/size.dart';
import 'package:flutter/material.dart';

import '../../../../utils/custom_color.dart';
import '../../../../utils/dimensions.dart';

Widget iconCreation(IconData icons, Color color, String text, {required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    child: Column(
      children: [
        CircleAvatar(
          radius: Dimensions.radius * 3,
          backgroundColor: color,
          child: Icon(icons, size: Dimensions.iconSizeLarge * 1.16, color: CustomColor.white),
        ),
        verticalSpace(Dimensions.heightSize * 0.5),
        Text(text, style: TextStyle(fontSize: Dimensions.smallestTextSize)),
      ],
    ),
  );
}
