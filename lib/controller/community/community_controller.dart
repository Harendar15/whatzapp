import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import 'package:adchat/helpers/local_storage.dart';
import 'package:adchat/utils/progress_dialog.dart';
import 'package:adchat/widget/picker/picker_widget.dart';
import 'package:adchat/utils/strings.dart';

import 'package:adchat/models/community.dart' as model;
import 'package:adchat/views/community/community_details_screen.dart';

import 'package:adchat/controller/repo/community_repository.dart';

final communityControllerProvider = Provider<CommunityController>((ref) {
  final repo = ref.read(communityRepositoryProvider);
  final controller = CommunityController(ref: ref, repo: repo);

  // ✅ prevent memory leak
  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});

class CommunityController {
  final Ref ref;
  final CommunityRepository repo;

  CommunityController({required this.ref, required this.repo});

  // ---------------- CONTROLLERS ----------------
  final TextEditingController communityNameController =
      TextEditingController();
  final TextEditingController communityHeadlineController =
      TextEditingController();

  // ---------------- STATE ----------------
  List<String> selectedContacts = [];
  List<String> selectedGroupsId = [];
  File? image;

  // ---------------- DISPOSE ----------------
  void dispose() {
    communityNameController.dispose();
    communityHeadlineController.dispose();
  }
  

  // ----------------------------------------------------
  // STREAM: My Communities
  // ----------------------------------------------------
  Stream<List<model.Community>> streamMyCommunities(String myUid) {
    return repo.myCommunities(myUid: myUid);
  }

  // ----------------------------------------------------
  // STREAM: Selected Community
  // ----------------------------------------------------
  Stream<List<model.Community>> streamSelectedCommunity(String myUid) {
    final cid = LocalStorage.getCommunityID();
    if (cid.isEmpty) return Stream.value([]);

    return repo.watchCommunity(cid).map((c) {
      if (c == null) return [];
      return c.membersUid.contains(myUid) ? [c] : [];
    });
  }

  // ----------------------------------------------------
  // CREATE COMMUNITY
  // ----------------------------------------------------
  Future<void> createCommunity(BuildContext context) async {
    ProgressDialog.showProgressDialog(
      loadingText: Strings.creatingCommunity,
    );

    try {
      final uid = LocalStorage.getMyUid();
      if (uid == null || uid.isEmpty) {
        throw "Missing UID";
      }

      final createdId = await repo.createCommunity(
        name: communityNameController.text.trim(),
        description: "",
        headline: communityHeadlineController.text.trim(),
        creatorUid: uid,
        membersUid: {
          uid,
          ...selectedContacts,
        }.toList(),
        communityImage: image,
      );

      LocalStorage.saveCommunityId(id: createdId);

      // reset
      communityNameController.clear();
      communityHeadlineController.clear();
      selectedContacts.clear();
      selectedGroupsId.clear();
      image = null;

      ProgressDialog.hideProgressDialog();
      Get.offAllNamed(CommunityDetailsScreen.routeName);

    } catch (e) {
      ProgressDialog.hideProgressDialog();
      debugPrint("createCommunity error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to create community")),
      );
    }
  }

  // ----------------------------------------------------
  // UPDATE COMMUNITY (ADMIN ONLY)
  // ----------------------------------------------------
  Future<void> updateCommunity(BuildContext context) async {
    ProgressDialog.showProgressDialog(
      loadingText: Strings.pleaseWaitAMoment,
    );

    try {
      final cid = LocalStorage.getCommunityID();
      if (cid.isEmpty) throw "No community selected";

      final existing = await repo.getCommunityOnce(cid);
      if (existing == null) throw "Community missing";

      final myUid = LocalStorage.getMyUid();
      if (myUid == null || !existing.admins.contains(myUid)) {
        throw "Only admins can update community";
      }

      // 1️⃣ add members
      if (selectedContacts.isNotEmpty) {
        await repo.addMembers(
          communityId: cid,
          uidsToAdd: selectedContacts,
        );
      }

      // 2️⃣ link groups
      for (final gid in selectedGroupsId) {
        await repo.linkGroup(
          communityId: cid,
          groupId: gid,
        );
      }

      selectedContacts.clear();
      selectedGroupsId.clear();

      ProgressDialog.hideProgressDialog();
      Get.offAllNamed(CommunityDetailsScreen.routeName);

    } catch (e) {
      ProgressDialog.hideProgressDialog();
      debugPrint("updateCommunity error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    }
  }

  // ----------------------------------------------------
  // REMOVE GROUPS FROM COMMUNITY (ADMIN ONLY)
  // ----------------------------------------------------
  Future<void> deleteGroupsFromCommunity(
    BuildContext context,
    List<String> groupsUid,
  ) async {
    ProgressDialog.showProgressDialog(
      loadingText: Strings.removingGroup,
    );

    try {
      final cid = LocalStorage.getCommunityID();
      if (cid.isEmpty) throw "No community selected";

      final existing = await repo.getCommunityOnce(cid);
      if (existing == null) throw "Community not found";

      final myUid = LocalStorage.getMyUid();
      if (myUid == null || !existing.admins.contains(myUid)) {
        throw "Only admins can remove groups";
      }

      final remaining = List<String>.from(existing.groupIds)
        ..removeWhere((g) => groupsUid.contains(g));

      await repo.updateCommunityFields(
        communityId: cid,
        groupsUid: remaining,
        admins: existing.admins,
      );

      ProgressDialog.hideProgressDialog();
      Get.offAllNamed(CommunityDetailsScreen.routeName);

    } catch (e) {
      ProgressDialog.hideProgressDialog();
      debugPrint("deleteGroups error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to remove groups")),
      );
    }
  }

  // ----------------------------------------------------
  // DELETE COMMUNITY (ADMIN ONLY)
  // ----------------------------------------------------
  Future<void> deleteCommunity(BuildContext context) async {
    ProgressDialog.showProgressDialog(
      loadingText: Strings.deletingCommunity,
    );

    try {
      final cid = LocalStorage.getCommunityID();
      if (cid.isEmpty) throw "No community selected";

      final existing = await repo.getCommunityOnce(cid);
      if (existing == null) throw "Community not found";

      final myUid = LocalStorage.getMyUid();
      if (myUid == null || !existing.admins.contains(myUid)) {
        throw "Only admins can delete community";
      }

      await repo.deleteCommunity(cid);
      LocalStorage.saveCommunityId(id: "");

      ProgressDialog.hideProgressDialog();
      Get.offAllNamed("/");

    } catch (e) {
      ProgressDialog.hideProgressDialog();
      debugPrint("deleteCommunity error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete community")),
      );
    }
  }

  // ----------------------------------------------------
  // IMAGE PICKERS
  // ----------------------------------------------------
  Future<void> selectImageFromCamera(BuildContext ctx) async {
    image = await pickImageFromCamera(ctx);
  }

  Future<void> selectImageFromGallery(BuildContext ctx) async {
    image = await pickImageFromGallery(ctx);
  }
}
