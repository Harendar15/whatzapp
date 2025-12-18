import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import '../../controller/repo/group_repository.dart';
import '../../models/group.dart';
import '../../utils/dimensions.dart';
import '../../views/chat/chat_screen.dart';
import 'package:adchat/widget/safe_image.dart';
import '../../widget/group/select_contacts_group.dart';
import '../../widget/picker/picker_widget.dart';

final selectedGroupContactsProvider =
    StateProvider<List<String>>((ref) => []);

class CreateGroupScreen extends ConsumerStatefulWidget {
  static const String routeName = '/create-group-screen';
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() =>
      _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  File? pickedImage;
  bool _loading = false;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await pickImageFromGallery(context);
    if (img != null) setState(() => pickedImage = img);
  }

  Future<void> _createGroup() async {
  final selected =
      ref.read(selectedGroupContactsProvider.notifier).state;

  if (nameController.text.trim().isEmpty || selected.isEmpty) return;

  setState(() => _loading = true);

  try {
    final repo = ref.read(groupRepositoryProvider);
    final user = repo.auth.currentUser!;

    final groupId = await repo.createGroup(
      name: nameController.text.trim(),
      groupImage: pickedImage,
      membersUid: {
        ...selected,
        user.uid,
      }.toList(),
      creatorUid: user.uid,
      description: descriptionController.text.trim(),
    );

    final snap =
        await repo.firestore.collection('groups').doc(groupId).get();
    final group = Group.fromMap(snap.data()!);

    ref.read(selectedGroupContactsProvider.notifier).state = [];

    Get.off(
      () => ChatScreen(
        name: group.name,
        uid: group.groupId,
        isGroupChat: true,
        isCommunityChat: false,
        profilePic: group.groupPic,
        isHideChat: false,
        groupData: group,
        communityData: null,
      ),
    );
  } finally {
    setState(() => _loading = false);
  }
}



@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Create Group"),
      centerTitle: true,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Dimensions.marginSize),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --------------------
            // GROUP IMAGE PICKER
            // --------------------
           GestureDetector(
  onTap: _pickImage,
  child: Stack(
    alignment: Alignment.bottomRight,
    children: [
      pickedImage != null
          ? ClipOval(
              child: Image.file(
                pickedImage!,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
            )
          : SafeImage(
              url: "",
              size: 90,
              borderColor: Colors.grey.shade300,
              borderWidth: 2,
            ),

      Container(
        decoration: const BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(6),
        child: const Icon(
          Icons.camera_alt,
          size: 16,
          color: Colors.white,
        ),
      ),
    ],
  ),
),


            const SizedBox(height: 20),

            // --------------------
            // GROUP NAME
            // --------------------
            TextField(
              controller: nameController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: "Group name",
                hintText: "Enter group name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // --------------------
            // DESCRIPTION
            // --------------------
            TextField(
              controller: descriptionController,
              maxLines: 2,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: "Description (optional)",
                hintText: "About this group",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // --------------------
            // CONTACT SELECTION
            // --------------------
            Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(bottom: 6),
              child: const Text(
                "Add members",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            Container(
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child:SelectContactsGroup(
  selectionProvider: selectedGroupContactsProvider,
),


            ),

            const SizedBox(height: 20),

            // --------------------
            // CREATE BUTTON
            // --------------------
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _createGroup,
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : const Text(
                        "Create Group",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}