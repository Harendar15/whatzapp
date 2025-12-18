import 'package:adchat/controller/repo/chat_repo.dart';
import 'package:adchat/models/group.dart';
import 'package:adchat/widget/safe_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:adchat/controller/repo/group_repository.dart';
import 'package:adchat/views/chat/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum _GroupMenuAction { addMember, details, deleteGroup }

class MyGroupsScreen extends ConsumerWidget {
  static const routeName = "/my-groups";

  const MyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsStream = ref.watch(chatRepositoryProvider).getChatGroups();

    return Scaffold(
      appBar: AppBar(title: const Text("My Groups"), centerTitle: true),
      body: StreamBuilder<List<Group>>(
        stream: groupsStream,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snap.data!;
          if (groups.isEmpty) {
            return const Center(child: Text("No groups created yet."));
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) => _GroupTile(group: groups[i]),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
class _GroupTile extends ConsumerWidget {
  final Group group;

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final isAdmin = group.admins.contains(myUid);

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          SafeImage(url: group.groupPic, size: 55),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text("${group.membersUid.length} members",
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          ElevatedButton(
            onPressed: () {
              Get.to(() => ChatScreen(
                    name: group.name,
                    uid: group.groupId,
                    isGroupChat: true,
                    isCommunityChat: false,
                    profilePic: group.groupPic,
                    isHideChat: false,
                    groupData: group,
                  ));
            },
            child: const Text("Message"),
          ),

          PopupMenuButton<_GroupMenuAction>(
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _GroupMenuAction.details,
                child: Text("View Details"),
              ),
              if (isAdmin)
                const PopupMenuItem(
                  value: _GroupMenuAction.deleteGroup,
                  child: Text(
                    "Delete Group",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
            onSelected: (action) {
              if (action == _GroupMenuAction.deleteGroup) {
                _confirmDeleteGroup(context, ref, myUid);
              }
              if (action == _GroupMenuAction.details) {
                Get.toNamed("/group-details", arguments: group);
              }
            },
          ),
        ],
      ),
    );
  }

  // 🔥 ADMIN CONFIRM DELETE (FIXED)
  void _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    String myUid,
  ) {
    Get.dialog(
      AlertDialog(
        title: const Text("Delete Group"),
        content: Text("Only admin can delete.\n\nDelete '${group.name}'?"),
        actions: [
          TextButton(onPressed: Get.back, child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(groupRepositoryProvider)
                    .deleteGroup(
                      groupId: group.groupId,
                      myUid: myUid,
                    );

                Get.back();
                Get.snackbar(
                  "Deleted",
                  "Group removed",
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar(
                  "Error",
                  "Only admin allowed",
                  backgroundColor: Colors.black,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
