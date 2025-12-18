import 'dart:io';
import 'package:get/get.dart';

// MODELS
import 'models/status_model.dart';

// SCREENS
import 'views/auth/login_screen.dart';
import 'views/auth/otp_screen.dart';
import 'views/auth/user_information_screen.dart';
import 'views/home/home_screen.dart';
import 'views/chat/chat_screen.dart';
import 'views/group/create_group_screen.dart';
import 'views/group/group_info_screen.dart';

// STATUS
import 'views/status/confirm_status_screen.dart';
import 'views/status/status_contacts_screen.dart';
import 'views/status/status_viewer_screen.dart';

// CONTACTS
import 'views/select_contacts/select_contacts_screen.dart';

// COMMUNITY
import 'views/community/community_screen.dart';
import 'views/community/community_details_screen.dart';

class AppRoutes {
  // ---------------- AUTH ----------------
  static moveToLogin() => Get.offAll(() => const LoginScreen());
  static moveToOtp() => Get.to(() => OTPScreen());
  static moveToUserInfo() => Get.off(() => const UserInformationScreen());
  static moveToHome() => Get.offAll(() => const HomeScreen());

  // ---------------- CONTACTS & CHAT ----------------
  static moveToSelectContacts() => Get.to(() => const SelectContactsScreen());

  static moveToChat(Map<String, dynamic> args) {
    Get.to(() => ChatScreen(
          name: args['name'] ?? '',
          uid: args['uid'] ?? '',
          isGroupChat: args['isGroupChat'] ?? false,
          isCommunityChat: args['isCommunityChat'] ?? false,
          profilePic: args['profilePic'] ??
              'https://cdn-icons-png.flaticon.com/512/149/149071.png',
          isHideChat: args['isHideChat'] ?? false,
          groupData: args['groupData'],
          communityData: args['communityData'],
          fromStatusReply: args['fromStatusReply'] ?? false,
        ));
  }

  // ---------------- STATUS ----------------
  static moveToStatusConfirm(File file) =>
      Get.to(() => ConfirmStatusScreen(file: file));

  static moveToStatusScreen(Status status) =>
      Get.to(() => StatusViewerScreen(ownerStatus: status));

  static moveToStatusContacts() =>
      Get.to(() => const StatusContactsScreen());

  // ---------------- GROUP ----------------
  static moveToCreateGroup() =>
      Get.to(() => const CreateGroupScreen());

  static moveToGroupInfo(groupData) =>
      Get.to(() => GroupInfoScreen(group: groupData));

  // ---------------- COMMUNITY ----------------
  static moveToCommunity(String id) =>
      Get.to(() => CommunityScreen(communityId: id));

  static moveToCommunityDetails() =>
      Get.to(() => const CommunityDetailsScreen());
}
