import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user_model.dart';
import 'package:adchat/widget/safe_image.dart';

class AddCommunityMemberScreen extends StatefulWidget {
  static const String routeName = '/add-community-member';
  final String communityId;
  final List<String> existingMembers;

  const AddCommunityMemberScreen({
    super.key,
    required this.communityId,
    required this.existingMembers,
  });

  @override
  State<AddCommunityMemberScreen> createState() =>
      _AddCommunityMemberScreenState();
}

class _AddCommunityMemberScreenState
    extends State<AddCommunityMemberScreen> {
  List<UserModel> allUsers = [];
  List<String> selected = [];

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    final snap = await FirebaseFirestore.instance.collection("users").get();

    setState(() {
      allUsers =
          snap.docs.map((d) => UserModel.fromMap(d.data())).toList();

      // remove already joined users
      allUsers.removeWhere(
          (u) => widget.existingMembers.contains(u.uid));
    });
  }

  Future<void> addMembers() async {
    if (selected.isEmpty) {
      Get.snackbar("Error", "Select at least one member");
      return;
    }

    await FirebaseFirestore.instance
        .collection("community")
        .doc(widget.communityId)
        .update({
      "membersUid": FieldValue.arrayUnion(selected),
    });

    Get.back();
    Get.snackbar("Success", "Members added successfully");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Members"),
        actions: [
          TextButton(
            onPressed: addMembers,
            child: const Text(
              "ADD",
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),

      body: allUsers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: allUsers.length,
              itemBuilder: (_, i) {
                final u = allUsers[i];
                final isSelected = selected.contains(u.uid);

                return ListTile(
                  leading: SafeImage(url: u.profilePic, size: 48),
                  title: Text(u.name),
                  subtitle: Text(u.phoneNumber),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selected.add(u.uid);
                        } else {
                          selected.remove(u.uid);
                        }
                      });
                    },
                  ),
                );
              },
            ),
    );
  }
}
