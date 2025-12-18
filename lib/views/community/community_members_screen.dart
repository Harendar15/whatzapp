// lib/views/community/community_members_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/community.dart';
import '../../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:adchat/widget/safe_image.dart';

class CommunityMembersScreen extends StatelessWidget {
  final Community community;
  const CommunityMembersScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final members = community.membersUid;
    final admins = community.admins;

    return Scaffold(
      appBar: AppBar(
        title: Text("Members (${members.length})"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            onPressed: () {
              Get.toNamed("/add-community-member", arguments: {
                "communityId": community.communityId,
                "members": community.membersUid,
              });
            },
          )
        ],
      ),

      body: members.isEmpty
          ? const Center(child: Text("No members in this community"))
          : FutureBuilder<List<UserModel>>(
              future: _fetchMembers(members),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snap.data!;
                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => Divider(height: 12),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final isAdmin = admins.contains(u.uid);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),

                      leading: SafeImage(url: u.profilePic, size: 52),

                      title: Row(
                        children: [
                          Text(
                            u.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "Admin",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            )
                          ]
                        ],
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.phoneNumber,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700),
                          ),
                          if (u.about.isNotEmpty)
                            Text(
                              u.about,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),

                      onTap: () => _memberActions(context, u, isAdmin),
                    );
                  },
                );
              },
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // FETCH USER DETAILS (CHUNKED)
  // ---------------------------------------------------------------------------
  Future<List<UserModel>> _fetchMembers(List<String> uids) async {
    List<UserModel> all = [];
    const chunk = 10;

    for (var i = 0; i < uids.length; i += chunk) {
      final slice = uids.skip(i).take(chunk).toList();
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .where("uid", whereIn: slice)
          .get();

      all.addAll(snap.docs.map((d) => UserModel.fromMap(d.data())).toList());
    }

    return all;
  }
  void _confirmRemoveMember(BuildContext context, UserModel u) {
  // 🚫 Prevent removing last admin
  final adminCount = community.admins.length;

  if (adminCount <= 1 && community.admins.contains(u.uid)) {
    Get.snackbar(
      "Action blocked",
      "You must assign another admin first",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.withOpacity(0.2),
    );
    return;
  }

  Get.dialog(
    AlertDialog(
      title: const Text("Remove member"),
      content: Text(
        "Remove ${u.name} from this community?",
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text("Cancel"),
        ),
        TextButton(
          child: const Text(
            "Remove",
            style: TextStyle(color: Colors.red),
          ),
          onPressed: () async {
            Get.back();

            try {
              await FirebaseFirestore.instance
                  .collection("community") // ✅ correct collection
                  .doc(community.communityId)
                  .update({
                "membersUid": FieldValue.arrayRemove([u.uid]),
                "admins": FieldValue.arrayRemove([u.uid]),
              });

              // 🔄 AUTO REFRESH
              Get.snackbar(
                "Removed",
                "${u.name} removed from community",
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.redAccent.withOpacity(0.15),
              );

              // force rebuild
              Get.offAndToNamed(
                "/community-members",
                arguments: community.communityId,
              );
            } catch (e) {
              Get.snackbar(
                "Error",
                "Failed to remove member",
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
        ),
      ],
    ),
  );
}

  // ---------------------------------------------------------------------------
  // MEMBER ACTION SHEET (VIEW PROFILE / MESSAGE / REMOVE)
  // ---------------------------------------------------------------------------
 void _memberActions(
  BuildContext context,
  UserModel u,
  bool isAdmin,
) {
  final bool iAmAdmin =
      community.admins.contains(FirebaseAuth.instance.currentUser!.uid);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => SafeArea(
      child: Wrap(
        children: [
          const SizedBox(height: 4),

          // ---------------- VIEW PROFILE ----------------
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("View Profile"),
            onTap: () => Navigator.pop(context),
          ),

          // ---------------- MESSAGE USER ----------------
          ListTile(
            leading: const Icon(Icons.chat_bubble),
            title: const Text("Message User"),
            onTap: () {
              Navigator.pop(context);
              Get.toNamed(
                "/mobile-chat-screen",
                arguments: {
                  "uid": u.uid,
                  "name": u.name,
                  "profilePic": u.profilePic,
                  "isGroupChat": false,
                  "isCommunityChat": false,
                },
              );
            },
          ),

          // ---------------- REMOVE MEMBER ----------------
          if (iAmAdmin && !isAdmin)
            ListTile(
              leading: const Icon(
                Icons.remove_circle,
                color: Colors.redAccent,
              ),
              title: const Text(
                "Remove from Community",
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveMember(context, u);
              },
            ),
        ],
      ),
    ),
  );
}
}