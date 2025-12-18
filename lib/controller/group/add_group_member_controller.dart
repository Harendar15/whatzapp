// lib/controller/add_group_member_controller.dart

import 'package:get/get.dart';

class AddGroupMemberController extends GetxController {
  RxList<String> selectedUserUids = <String>[].obs;

  void toggle(String uid) {
    if (selectedUserUids.contains(uid)) {
      selectedUserUids.remove(uid);
    } else {
      selectedUserUids.add(uid);
    }
  }
}
