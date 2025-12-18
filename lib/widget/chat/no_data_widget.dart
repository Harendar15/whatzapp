// lib/widget/chat/no_data_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import 'package:adchat/controller/repo/select_contact_repository.dart';
import '../../../../controller/call/call_history_controller.dart';
import '../../../../models/user_model.dart';
import '../../../../utils/dimensions.dart';
import '../../../../utils/strings.dart';
import '../../../../utils/custom_color.dart';
import 'package:adchat/widget/safe_image.dart';

Widget noData(BuildContext context, WidgetRef ref, {bool isWidget = false}) {
  final callController = Get.put(CallHistoryController());

  return ref.watch(getContactsProvider).when(
    data: (contactList) {
      return StreamBuilder<List<UserModel>>(
        stream: callController.getContactList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }

          final firebaseUsers = snapshot.data ?? [];

          final userContactList =
              firebaseUsers.map((u) => u.phoneNumber).toList();
          final userImage = firebaseUsers.map((u) => u.profilePic).toList();
          final userUid = firebaseUsers.map((u) => u.uid).toList();

          final localPhones = <String>[];
          for (var c in contactList) {
            for (var p in c.phones) {
              localPhones.add(p.number.replaceAll(RegExp(r'[^0-9+]'), ''));
            }
          }

          final result =
              localPhones.toSet().intersection(userContactList.toSet()).toList();

          if (result.isEmpty) {
            return Center(
              child: !isWidget
                  ? const Text(
                      Strings.noContactsAreAvailable,
                      textAlign: TextAlign.center,
                    )
                  : Container(),
            );
          }

          for (var number in result) {
            final idx = userContactList.indexOf(number);
            if (idx >= 0) {
              final uid = userUid[idx];

              if (!callController.uidWhoCanSee.contains(uid)) {
                callController.uidWhoCanSee.add(uid);
              }

              if (!callController.userNumberList.contains(number)) {
                callController.userNumberList.add(number);
              }
            }
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: Dimensions.heightSize * 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    result.length >= 5 ? 5 : result.length,
                    (index) {
                      final idx = userContactList.indexOf(result[index]);

                      return SafeImage(
                        url: userImage[idx],
                        size: Dimensions.radius * 4,
                      );
                    },
                  ),
                ),
              ),
              if (!isWidget)
                Text(
                  "${result.length} ${Strings.noChatText}",
                  style: TextStyle(
                    color: Get.isDarkMode ? CustomColor.greyColor : Colors.black,
                  ),
                ),
            ],
          );
        },
      );
    },
    loading: () => const SizedBox(),
    error: (e, _) => Center(child: Text(e.toString())),
  );
}
