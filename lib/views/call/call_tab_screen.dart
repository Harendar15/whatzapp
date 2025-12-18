// lib/views/call/call_tab_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/call/call_history_controller.dart';
import '../../models/call_model.dart';
import '../../utils/strings.dart';
import '../../utils/custom_color.dart';
import '../../widget/custom_loader.dart';
import 'package:adchat/widget/safe_image.dart';
import 'package:firebase_auth/firebase_auth.dart';


class CallTabScreen extends StatelessWidget {
  static const String routeName = '/call-tab';
  CallTabScreen({super.key});

  final callHistoryController = Get.put(CallHistoryController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Get.isDarkMode ? CustomColor.bgColorDarkMode : CustomColor.white,
      appBar: AppBar(
        title: Text(
          Strings.calls.tr,
          style: TextStyle(
            color:
                Get.isDarkMode ? CustomColor.white : CustomColor.black,
          ),
        ),
        backgroundColor:
            Get.isDarkMode ? CustomColor.bgColorDarkMode : CustomColor.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Get.isDarkMode ? CustomColor.white : CustomColor.black,
        ),
      ),
      body: StreamBuilder<List<CallModel>>(
        stream: callHistoryController.getCallHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CustomLoader();
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(Strings.noCallData.tr));
          }
          final calls = snapshot.data!;
          return ListView.separated(
            itemCount: calls.length,
            reverse: true,
            separatorBuilder: (_, __) => const Divider(),
           itemBuilder: (context, index) {
            final c = calls[index];
            final myUid = FirebaseAuth.instance.currentUser!.uid;

            // 👉 Decide which user to show
            final bool amICaller = c.callerId == myUid;

            final String displayName =
                amICaller ? c.receiverName : c.callerName;

            final String displayImage =
                amICaller ? c.receiverImage : c.callerImage;

            return ListTile(
              leading: SafeImage(
                url: displayImage,
                size: 45,
              ),
              title: Text(displayName),
              subtitle: Text('${c.type} • ${c.status}'),
              trailing: Text(
                DateTime.fromMillisecondsSinceEpoch(c.timestamp)
                    .toLocal()
                    .toString(),
                style: const TextStyle(fontSize: 12),
              ),
            );
          },

          );
        },
      ),
    );
  }
}
