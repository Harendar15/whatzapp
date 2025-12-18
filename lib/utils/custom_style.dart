import 'package:flutter/material.dart';

import 'custom_color.dart';
import 'dimensions.dart';

class CustomStyle {
  static var smallTextStyle = TextStyle(
    fontSize: Dimensions.smallestTextSize,
    // color: CustomColor.primaryButtonColor,
  );

  static var extraSmallTextStyle = TextStyle(
    fontSize: Dimensions.smallestTextSize * 0.9,
    // ✅ Updated to new Flutter API (no precision loss warning)
    color: CustomColor.white.withOpacity(0.6),
  );
}
