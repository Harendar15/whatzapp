import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import 'package:adchat/models/group.dart';
import 'package:adchat/models/user_model.dart';
import 'package:adchat/controller/repo/group_repository.dart';
import 'package:adchat/widget/group/group_admin_panel.dart';

class GroupInfoScreen extends ConsumerWidget {
  final Group group;

  const GroupInfoScreen({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(groupRepositoryProvider);
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    /// ✅ ADMIN CHECK (creator is also admin)
    final bool isAdmin =
        group.creatorUid == myUid || group.admins.contains(myUid);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Group Info"),
      ),
      body: FutureBuilder<List<UserModel>>(
        future: repo.fetchGroupMembers(group.membersUid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text("No members found"));
          }

          return GroupAdminPanel(
            // ---------------- BASIC INFO ----------------
            groupName: group.name,
            groupImage: group.groupPic,
            members: snap.data!,
            creatorUid: group.creatorUid,
            admins: group.admins,

            // ---------------- ADMIN ACTIONS ----------------
            onAddMembers: isAdmin
                ? () => Get.toNamed(
                      "/add-group-member",
                      arguments: group,
                    )
                : null,

            onRemoveMember: isAdmin
                ? (uid) async {
                    await repo.removeMember(group.groupId, uid);
                    Get.snackbar("Removed", "Member removed");
                  }
                : null,

            onPromoteAdmin: isAdmin
                ? (uid) async {
                    await repo.promoteAdmin(group.groupId, uid);
                    Get.snackbar("Promoted", "User is now admin");
                  }
                : null,

            onDemoteAdmin: isAdmin
                ? (uid) async {
                    await repo.demoteAdmin(group.groupId, uid);
                    Get.snackbar("Demoted", "Admin removed");
                  }
                : null,

            /// ✅ REQUIRED PARAM (ERROR FIXED)
            // onEditGroup: isAdmin
            //     ? () {
            //         Get.toNamed(
            //           "/edit-group-screen",
            //           arguments: group,
            //         );
            //       }
            //     : null,

           onDeleteGroup: isAdmin
              ? () async {
                  await repo.deleteGroup(
                    groupId: group.groupId,
                    myUid: myUid,
                  );

                  Get.offAllNamed("/home");
                  Get.snackbar("Deleted", "Group removed");
                }
              : null,


            // ---------------- USER ACTION ----------------
            onExitGroup: () async {
              await repo.exitGroup(group.groupId);
              Get.back();
              Get.snackbar("Exited", "You left the group");
            },
          );
        },
      ),
    );
  }
}
