import 'package:flutter/material.dart';

import '../../../../utils/custom_color.dart';
import '../../../../utils/dimensions.dart';

Widget labelWidget(String label) {
  return Container(
    margin: EdgeInsets.symmetric(
      horizontal: Dimensions.marginSize,
      vertical: Dimensions.marginSize * 0.5,
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: CustomColor.greyColor,
      ),
    ),
  );
}
