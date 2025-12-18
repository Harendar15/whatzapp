import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  RxString countryName = 'India'.obs;
  RxString countryCode = '91'.obs;
  final phoneController = TextEditingController();

  final isLoading = false.obs;
  final isVerifyCode = false.obs;
  RxBool isDemoAccount = false.obs;
  RxBool isUserUpdate = false.obs;

  @override
  void onClose() {
    // more stable than dispose() in GetX controller
    phoneController.dispose();
    super.onClose();
  }

  /// Reset all fields (useful after failed login or logout)
  void reset() {
    phoneController.clear();
    isLoading.value = false;
    isVerifyCode.value = false;
    isDemoAccount.value = false;
    isUserUpdate.value = false;
  }

  void pickCountry(BuildContext context) {
    showCountryPicker(
      context: context,
      countryListTheme: CountryListThemeData(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      onSelect: (country) {
        countryName.value = country.name;
        countryCode.value = country.phoneCode;
      },
    );
  }

  String get fullPhone => '+${countryCode.value}${phoneController.text}';
}
