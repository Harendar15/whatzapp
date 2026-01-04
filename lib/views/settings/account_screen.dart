import 'package:adchat/controller/settings/settings_screen_controller.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:adchat/utils/custom_color.dart';
import 'package:adchat/utils/dimensions.dart';
import 'package:adchat/utils/size.dart';
import 'package:adchat/utils/strings.dart';
import 'package:adchat/views/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../helpers/prefs_services.dart';
import '../../controller/language/language_controller.dart';

class AccountScreen extends ConsumerWidget {
  AccountScreen({super.key});

  final controller = Get.put(SettingsScreenController());
  final languageController = Get.put(LanguageController());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.account.tr)),
      body: _bodyWidget(context, ref),
    );
  }

  Widget _bodyWidget(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        verticalSpace(Dimensions.heightSize * 0.6),
        _listOfTopicWidget(context, ref),
      ],
    );
  }

  Widget _listOfTopicWidget(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _customListWidget(
          icon: Icons.delete_forever,
          title: Strings.deleteMyAccount.tr,
          goTo: () => _confirmDeleteDialog(context, ref),
        ),
        _customListWidget(
          icon: Icons.language,
          title: Strings.changeLanguage.tr,
          goTo: () => _showDialog(context),
        ),
        _customListWidget(
          icon: Icons.logout,
          title: Strings.logOut.tr,
          goTo: () async {
            await FirebaseAuth.instance.signOut();
            await PrefHelper.logout();
            Get.offAll(const LoginScreen());
          },
        ),
      ],
    );
  }

  Widget _customListWidget({
    required IconData icon,
    required String title,
    required VoidCallback goTo,
  }) {
    return ListTile(
      onTap: goTo,
      minLeadingWidth: Dimensions.widthSize * 3,
      leading: Padding(
        padding: EdgeInsets.all(Dimensions.defaultPaddingSize * 0.27),
        child: Icon(icon, color: CustomColor.greyColor),
      ),
      title: Text(title),
    );
  }

  void _confirmDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(Strings.deleteMyAccount.tr),
        content: Text(
          Strings.deleteAccount.tr,
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(Strings.no.tr),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _deleteAccount(context, ref);
            },
            child: Text(
              Strings.yes.tr,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(authRepositoryProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await repo.deleteAccount(context);
    } finally {
      if (Get.isDialogOpen == true) Get.back();
    }
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Obx(
          () => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Dimensions.widthSize * 3,
              vertical: Dimensions.heightSize,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                languageController.moreList.length,
                (index) => TextButton(
                  onPressed: () {
                    languageController.onChangeLanguage(
                      languageController.moreList[index],
                      index,
                    );
                    Get.back();
                  },
                  child: Text(
                    languageController.moreList[index].tr,
                    style: TextStyle(
                      color: languageController.selectedLanguage.value ==
                              languageController.moreList[index]
                          ? CustomColor.primaryColor
                          : Get.isDarkMode
                              ? CustomColor.white
                              : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}










































































































































































































































































































































































