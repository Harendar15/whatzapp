import 'package:get/get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../controller/repo/group_repository.dart';

final groupControllerProvider = Provider((ref) {
  return GroupController(ref);
});

class GroupController {
  final Ref ref;
  GroupController(this.ref);

  GroupRepository get _repo => ref.read(groupRepositoryProvider);

  // ------------------------------------------------------------
  // CREATE GROUP (UI → Repository)
  // ------------------------------------------------------------
  Future<String> createGroup({
    required String name,
    required List<String> members,
    required String creatorUid,
    required File? image,
    String description = "",
    String? communityId,
    bool isAnnouncement = false,
  }) async {
    if (members.isEmpty) {
      throw Exception("Group must have at least 1 member");
    }

    if (!members.contains(creatorUid)) {
      members.add(creatorUid);
    }

    return await _repo.createGroup(
      name: name,
      membersUid: members,
      creatorUid: creatorUid,
      groupImage: image,
      communityId: communityId,
      isAnnouncementGroup: isAnnouncement,
      description: description, 
    );
  }
  Future<void> deleteGroup(String groupId) async {
  final myUid = FirebaseAuth.instance.currentUser!.uid;

  await _repo.deleteGroup(
    groupId: groupId,
    myUid: myUid,
  );
}

  // ------------------------------------------------------------
  // ADD MEMBER (E2E WRAP KEYS)
  // ------------------------------------------------------------
  Future<void> addMember(String groupId, String uid) async {
    await _repo.addMemberWithE2E(
      groupId: groupId,
      newMemberUid: uid,
    );
  }

  // ------------------------------------------------------------
  // REMOVE MEMBER
  // ------------------------------------------------------------
  Future<void> removeMember(String groupId, String uid) async {
    await _repo.removeMember(groupId, uid);
  }

  // ------------------------------------------------------------
  // SET ADMINS
  // ------------------------------------------------------------
  Future<void> setAdmins(String groupId, List<String> admins) async {
    await _repo.setAdmins(groupId, admins);
  }
}
