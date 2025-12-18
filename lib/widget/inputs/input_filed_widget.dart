import 'package:adchat/utils/dimensions.dart';
import 'package:flutter/material.dart';

import '../../../../utils/custom_color.dart';
import '../../../../utils/strings.dart';

Widget inputFieldWidget(
  BuildContext context, {
  required VoidCallback onTap,
  required name,
}) {
  return Container(
    margin: EdgeInsets.only(top: Dimensions.marginSize * 0.5),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            autofocus: true,
            controller: name,
            decoration: const InputDecoration(
              hintText: Strings.enterYourName,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: CustomColor.primaryColor),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Expanded(
          flex: 0,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            icon: const Icon(Icons.emoji_emotions_outlined),
          ),
        )
      ],
    ),
  );
}
