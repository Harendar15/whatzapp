// lib/views/community/select_group_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import '../../controller/community/community_controller.dart';

class SelectGroup extends ConsumerStatefulWidget {
  final List<String> groupId; // not used but kept for compatibility
  const SelectGroup({super.key, required this.groupId});

  @override
  ConsumerState<SelectGroup> createState() => _SelectGroupState();
}

class _SelectGroupState extends ConsumerState<SelectGroup> {
  List<String> myAdminGroups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminGroups();
  }

  Future<void> _loadAdminGroups() async {
    // You can replace this Firestore path if your groups collection is different.
    final snap = await FirebaseFirestore.instance.collection("groups").get();

    final myUid = ref.read(communityControllerProvider)
        .repo
        .auth
        .currentUser!
        .uid;

    /// Filter only groups where user is admin
    final adminGroups = snap.docs.where((d) {
      final data = d.data();
      final meta = data["meta"] ?? {};
      final admins = List<String>.from(data["admins"] ?? []);
      return admins.contains(myUid);
    }).toList();

    myAdminGroups = adminGroups.map((d) => d.id).toList();
    loading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(communityControllerProvider);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (myAdminGroups.isEmpty) {
      return const Center(
        child: Text("You are not an admin of any group."),
      );
    }

    return ListView.builder(
        itemCount: myAdminGroups.length,
        itemBuilder: (_, index) {
          final gid = myAdminGroups[index];
          final isSelected = controller.selectedGroupsId.contains(gid);

          return ListTile(
            leading: const Icon(Icons.group),
            title: Text("Group ID: $gid"),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.circle_outlined),
            onTap: () {
              setState(() {
                if (isSelected) {
                  controller.selectedGroupsId.remove(gid);
                } else {
                  controller.selectedGroupsId.add(gid);
                }
              });
            },
          );
        },
      );
  }
}
