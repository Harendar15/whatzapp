// lib/views/group/add_group_member_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user_model.dart';
import '../../widget/custom_loader.dart';
import '../../controller/group/add_group_member_controller.dart';
import 'package:adchat/widget/safe_image.dart';


class AddGroupMemberScreen extends StatefulWidget {
  static const String routeName = '/add-group-member';

  final String groupId;
  final List<String> membersUid;
  final Future<List<UserModel>> Function() fetchContacts;

  const AddGroupMemberScreen({
    super.key,
    required this.groupId,
    required this.membersUid,
    required this.fetchContacts,
  });

  @override
  State<AddGroupMemberScreen> createState() => _AddGroupMemberScreenState();
}

class _AddGroupMemberScreenState extends State<AddGroupMemberScreen> {
  final controller = Get.put(AddGroupMemberController());
  bool _loading = true;
  List<UserModel> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final all = await widget.fetchContacts();
    setState(() {
      _contacts =
          all.where((u) => !widget.membersUid.contains(u.uid)).toList();
      _loading = false;
    });
  }

  void _done() => Get.back(result: controller.selectedUserUids.toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Members"),
        actions: [
          TextButton(
            onPressed: _done,
            child: const Text("Done", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (c, i) {
                final u = _contacts[i];
                final selected =
                    controller.selectedUserUids.contains(u.uid);

                return ListTile(
                  leading: SafeImage(url: u.profilePic, size: 50),
                  title: Text(u.name),
                  subtitle: Text(u.phoneNumber),
                  trailing: Checkbox(
                    value: selected,
                    onChanged: (_) => controller.toggle(u.uid),
                  ),
                  onTap: () => controller.toggle(u.uid),
                );
              },
            ),
    );
  }
}
