import 'package:adchat/controller/settings/settings_screen_controller.dart';
import 'package:adchat/utils/custom_color.dart';
import 'package:adchat/utils/dimensions.dart';
import 'package:adchat/utils/size.dart';
import 'package:adchat/utils/strings.dart';
import 'package:adchat/views/auth/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../helpers/prefs_services.dart';
import '../../controller/language/language_controller.dart';
import '../../widget/picker/picker_widget.dart';

class AccountScreen extends StatelessWidget {
  AccountScreen({super.key});

  final controller = Get.put(SettingsScreenController());
  final languageController = Get.put(LanguageController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.account.tr)),
      body: _bodyWidget(context),
    );
  }

  _bodyWidget(BuildContext context) {
    return ListView(
      children: [
        verticalSpace(Dimensions.heightSize * 0.6),
        _listOfTopicWidget(context)
      ],
    );
  }

  _listOfTopicWidget(BuildContext context) {
    return Column(
      children: [
        _customListWidget(
          icon: Icons.delete,
          title: Strings.deleteMyAccount.tr,
          goTo: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  content: Text(Strings.deleteAccount.tr),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: Text(Strings.no.tr),
                    ),
                    TextButton(
                      onPressed: () {
                        deleteAccount(context);
                      },
                      child: Text(Strings.yes.tr),
                    ),
                  ],
                );
              },
            );
          },
        ),
        _customListWidget(
          icon: Icons.language,
          title: Strings.changeLanguage.tr,
          goTo: () {
            _showDialog(context);
          },
        ),
        _customListWidget(
          icon: Icons.logout,
          title: Strings.logOut.tr,
          goTo: () {
            PrefHelper.logout();
            Get.offAll(const LoginScreen());
            FirebaseAuth.instance.signOut();
          },
        ),
      ],
    );
  }

  _customListWidget({
    required IconData icon,
    required String title,
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
    );
  }

  _showDialog(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Obx(
            () => Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: Dimensions.widthSize * 3,
                  vertical: Dimensions.heightSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    languageController.moreList.length,
                    (index) => Container(
                          alignment: Alignment.centerLeft,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: MediaQuery.of(context).size.width * 0.5,
                          padding: EdgeInsets.symmetric(
                              horizontal: Dimensions.widthSize * 1,
                              vertical: Dimensions.heightSize * 0.5),
                          child: TextButton(
                              onPressed: () {
                                languageController.onChangeLanguage(
                                    languageController.moreList[index], index);
                                Get.back();
                              },
                              child: Text(
                                languageController.moreList[index].tr,
                                style: TextStyle(
                                  color: languageController
                                              .selectedLanguage.value ==
                                          languageController.moreList[index]
                                      ? CustomColor.primaryColor
                                      : Get.isDarkMode
                                          ? CustomColor.white
                                          : Colors.black,
                                ),
                              )),
                        )),
              ),
            ),
          );
        });
  }

  Future<void> deleteAccount(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final uid = user.uid;

    // Allowed collections in your rules
    final usersDoc     = FirebaseFirestore.instance.collection('users').doc(uid);
    final tokenDoc     = FirebaseFirestore.instance.collection('deviceTokens').doc(uid);

    // Delete allowed documents
    await Future.wait([
      usersDoc.delete(),
      tokenDoc.delete(),
    ]);

    // Delete Firebase Auth account
    await user.delete();

    PrefHelper.logout();
    Get.offAll(() => const LoginScreen());
    showSnackBar(context: context, content: 'Account deleted successfully!');

  } catch (e) {
    debugPrint("❌ Account deletion failed: $e");
    showSnackBar(context: context, content: e.toString());
  }
}

}