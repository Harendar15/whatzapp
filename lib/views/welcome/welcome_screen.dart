// lib/views/welcome/welcome_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../helpers/prefs_services.dart';
import '../../utils/dimensions.dart';
import '../../utils/size.dart';
import '../../utils/strings.dart';
import '../../utils/custom_color.dart';
import '../../widget/custom_button.dart';
import '../../utils/assets.dart';
import '../auth/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  static const routeName = '/welcome';

  const WelcomeScreen({super.key});

Future<void> _onAgreePressed(BuildContext context) async {
  debugPrint("🟢 [Welcome] AGREE pressed");

  await PrefHelper.saveIntroStatus(isCompleted: true);
  // await Future.delayed(const Duration(milliseconds: 100));
  bool value =  PrefHelper.isCompleted();
  debugPrint("✅ [Welcome] PrefHelper.isCompleted after save => $value");

  if (value) {
    debugPrint("➡️ Navigating to LoginScreen...");
    Get.offAllNamed(LoginScreen.routeName);
  } else {
    debugPrint("❌ Still not completed, staying on Welcome...");
  }
}

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            verticalSpace(Dimensions.heightSize * 4),
            Text(
              Strings.welcome,
              style: TextStyle(
                fontSize: Dimensions.extraLargeTextSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: size.height / 9),

            // Your logo
            Image.asset(
              Assets.appLogo,
              scale: 1.9,
            ),

            SizedBox(height: size.height / 9),
            Container(
              margin: EdgeInsets.symmetric(horizontal: Dimensions.marginSize),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: Strings.readOur,
                  style: TextStyle(
                    color: Get.isDarkMode ? Colors.white : Colors.black,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: Strings.privacyPolicy,
                      recognizer: TapGestureRecognizer()..onTap = () {},
                      style: const TextStyle(color: CustomColor.primaryColor),
                    ),
                    const TextSpan(
                      text: Strings.tapAgree,
                    ),
                    TextSpan(
                      text: Strings.termsOfService,
                      recognizer: TapGestureRecognizer()..onTap = () {},
                      style: const TextStyle(color: CustomColor.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
            verticalSpace(Dimensions.heightSize * 3),
            SizedBox(
              width: size.width * 0.75,
              child: CustomButton(
                text: Strings.agree,
                onPressed: () => _onAgreePressed(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
