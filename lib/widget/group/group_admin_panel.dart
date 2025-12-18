import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/user_model.dart';
import '../../../widget/safe_image.dart';

class GroupAdminPanel extends StatelessWidget {
  final String groupName;
  final String groupImage;
  final List<UserModel> members;
  final String creatorUid;
  final List<String> admins;

  // ✅ ALL CALLBACKS OPTIONAL (IMPORTANT)
  final VoidCallback? onAddMembers;
  final void Function(String)? onRemoveMember;
  final void Function(String)? onPromoteAdmin;
  final void Function(String)? onDemoteAdmin;
  final VoidCallback? onEditGroup;
  final VoidCallback? onExitGroup;
  final VoidCallback? onDeleteGroup;

  const GroupAdminPanel({
    super.key,
    required this.groupName,
    required this.groupImage,
    required this.members,
    required this.creatorUid,
    required this.admins,
    this.onAddMembers,
    this.onRemoveMember,
    this.onPromoteAdmin,
    this.onDemoteAdmin,
    this.onEditGroup,
    this.onExitGroup,
    this.onDeleteGroup,
  });

  bool _isAdmin(String uid) => admins.contains(uid);

  @override
  Widget build(BuildContext context) {
   

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ---------------- HEADER ----------------
        Column(
          children: [
            SafeImage(url: groupImage, size: 90, isCircular: true),
            const SizedBox(height: 10),
            Text(
              groupName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${members.length} participants",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // ✏️ EDIT GROUP (ADMIN ONLY)
            if (onEditGroup != null)
              ElevatedButton.icon(
                onPressed: onEditGroup,
                icon: const Icon(Icons.edit),
                label: const Text("Edit Group Info"),
              ),
          ],
        ),

        const SizedBox(height: 30),

        // ---------------- MEMBERS ----------------
        const Text(
          "Participants",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),

        ...members.map((u) {
          final isCreator = u.uid == creatorUid;
          final isAdmin = _isAdmin(u.uid);

          return ListTile(
            leading: SafeImage(url: u.profilePic, size: 45),
            title: Text(u.name),
            subtitle: Text(isAdmin ? "Admin" : ""),
            trailing: (!isCreator &&
                    (onRemoveMember != null ||
                        onPromoteAdmin != null ||
                        onDemoteAdmin != null))
                ? PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == "remove" && onRemoveMember != null) {
                        onRemoveMember!(u.uid);
                      }
                      if (v == "promote" && onPromoteAdmin != null) {
                        onPromoteAdmin!(u.uid);
                      }
                      if (v == "demote" && onDemoteAdmin != null) {
                        onDemoteAdmin!(u.uid);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!isAdmin && onPromoteAdmin != null)
                        const PopupMenuItem(
                          value: "promote",
                          child: Text("Make Admin"),
                        ),
                      if (isAdmin && onDemoteAdmin != null)
                        const PopupMenuItem(
                          value: "demote",
                          child: Text("Remove Admin"),
                        ),
                      if (onRemoveMember != null)
                        const PopupMenuItem(
                          value: "remove",
                          child: Text("Remove Member"),
                        ),
                    ],
                  )
                : (isCreator
                    ? const Text(
                        "Creator",
                        style: TextStyle(color: Colors.green),
                      )
                    : null),
          );
        }),

        const SizedBox(height: 20),

        // ➕ ADD MEMBERS (ADMIN ONLY)
        if (onAddMembers != null)
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.group_add),
            ),
            title: const Text("Add Members"),
            onTap: onAddMembers,
          ),

        const Divider(),

        // 🚪 EXIT GROUP (ALL MEMBERS)
        if (onExitGroup != null)
          ListTile(
            leading:
                const Icon(Icons.logout, color: Colors.redAccent, size: 28),
            title: const Text(
              "Exit Group",
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: onExitGroup,
          ),

        // 🗑️ DELETE GROUP (ADMIN ONLY – PASSED FROM PARENT)
        if (onDeleteGroup != null)
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red, size: 28),
            title: const Text(
              "Delete Group",
              style: TextStyle(color: Colors.red),
            ),
            onTap: onDeleteGroup,
          ),
      ],
    );
  }
}
