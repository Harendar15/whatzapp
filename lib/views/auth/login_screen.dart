// lib/views/auth/login_screen.dart
// Cleaned LoginScreen: kept your logic but defensive and stable

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import '/controller/auth/login_controller.dart';
import '/utils/dimensions.dart';
import '/utils/size.dart';
import '/utils/strings.dart';
import '/utils/custom_color.dart';
import 'package:adchat/widget/custom_button.dart';
import 'package:adchat/widget/custom_loader.dart';
import 'package:adchat/widget/picker/picker_widget.dart';
import 'package:adchat/controller/repo/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
 final controller = Get.find<LoginController>();


  var underlineInputBorder = const UnderlineInputBorder(
    borderSide: BorderSide(color: CustomColor.primaryColor),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBarWidget(context),
      body: _bodyWidget(context),
    );
  }

Widget _bodyWidget(BuildContext context) {
  return SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: Dimensions.marginSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _hintTextWidget(context),
          _countryPickerWidget(context),
          _inputFieldWidget(context),
          SizedBox(height: Dimensions.marginSize * 2),
          _buttonWidget(context),
        ],
      ),
    ),
  );
}

  Widget _hintTextWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.25),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: Strings.verifyYourPhoneNumber.tr,
          style: TextStyle(
            color: Get.isDarkMode ? Colors.white : Colors.black,
          ),
          children: <TextSpan>[
            TextSpan(
              text: Strings.whatsMynum.tr,
              recognizer: TapGestureRecognizer()..onTap = () {},
              style: const TextStyle(color: CustomColor.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countryPickerWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Dimensions.marginSize * 2.5,
        vertical: Dimensions.marginSize * 0.5,
      ),
      child: Column(
        children: [
          Obx(() {
            return TextFormField(
              decoration: InputDecoration(
                enabledBorder: underlineInputBorder,
                hintText: controller.countryName.value,
                hintStyle: TextStyle(
                  fontSize: Dimensions.extraSmallTextSize * 1.1,
                  fontWeight: FontWeight.w400,
                  color: Get.isDarkMode ? CustomColor.white : Colors.black,
                ),
                suffixIcon: const Icon(
                  Icons.arrow_drop_down_outlined,
                  color: CustomColor.primaryColor,
                ),
                contentPadding: EdgeInsets.only(
                  left: Dimensions.marginSize * 3,
                  top: Dimensions.marginSize * 0.6,
                  bottom: 0,
                ),
              ),
              readOnly: true,
              onTap: () {
            
                  controller.pickCountry(context);

              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buttonWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: Dimensions.marginSize,
      ),
      child: Obx(
        () => controller.isLoading.isTrue
            ? const CustomLoader()
            : CustomButton(
                onPressed: () {
                  // validate & sign in
                  String phoneNumber = controller.phoneController.text.trim();
                  if (phoneNumber.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fill out all the fields')),
                    );
                    return;
                  }
                  // use Riverpod provider to sign in
                  ref.read(authRepositoryProvider).signInWithPhone(
                    context,
                    '+${controller.countryCode.value}$phoneNumber',
                  );
                },
                text: Strings.next.tr,
              ),
      ),
    );
  }

  Widget _inputFieldWidget(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Dimensions.marginSize * 2.5,
      ),
      child: Column(
        children: [
          Obx(() {
            return Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "+${controller.countryCode.value}",
                      enabledBorder: underlineInputBorder,
                      hintStyle: TextStyle(
                        fontSize: Dimensions.extraSmallTextSize * 1.1,
                        fontWeight: FontWeight.w400,
                        color: Get.isDarkMode ? CustomColor.white : Colors.black,
                      ),
                    ),
                    readOnly: true,
                  ),
                ),
                horizontalSpace(Dimensions.widthSize),
                Expanded(
                  flex: 3,
                  child: TextField(

                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    controller: controller.phoneController,
                    decoration: InputDecoration(
                      hintText: Strings.phoneNumber.tr,
                      enabledBorder: underlineInputBorder,
                    ),
                  ),
                ),
              ],
            );
          }),
          verticalSpace(Dimensions.heightSize * 3),
          InkWell(
            onTap: () {
              controller.isDemoAccount.value = !controller.isDemoAccount.value;
              if (controller.isDemoAccount.value) {
                controller.phoneController.text = '1927033582';
              } else {
                controller.phoneController.clear();
              }
            },
            child: Obx(
              () => Text(
                controller.isDemoAccount.value
                    ? Strings.createAnAccount.tr
                    : Strings.demoUser,
                style: TextStyle(
                  fontSize: Dimensions.smallestTextSize * 1.1,
                  color: CustomColor.primaryColor.withOpacity( 0.6),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  AppBar _appBarWidget(BuildContext context) => AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          Strings.enterYourPhoneNumber.tr,
          style: const TextStyle(
            color: CustomColor.primaryColor,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      );
}
