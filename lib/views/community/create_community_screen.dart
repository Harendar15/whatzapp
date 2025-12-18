import 'dart:io';

import 'package:adchat/controller/repo/community_repository.dart';
import 'package:adchat/widget/picker/picker_widget.dart';
import 'package:adchat/widget/safe_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adchat/helpers/local_storage.dart';
import 'package:adchat/widget/group/select_contacts_group.dart';

final selectedCommunityMembersProvider =
    StateProvider<List<String>>((ref) => []);

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() =>
      _CreateCommunityScreenState();
}

class _CreateCommunityScreenState
    extends ConsumerState<CreateCommunityScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();

  File? _image;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await pickImageFromGallery(context);
    if (img != null) setState(() => _image = img);
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final members = ref.read(selectedCommunityMembersProvider);

    if (name.isEmpty) {
      _snack("Enter community name");
      return;
    }

    if (members.isEmpty) {
      _snack("Select at least one member");
      return;
    }

    final creatorUid = LocalStorage.getMyUid();
    if (creatorUid == null) {
      _snack("User not logged in");
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(communityRepositoryProvider);

      await repo.createCommunity(
        name: name,
        description: _desc.text.trim(),
        communityImage: _image,
        creatorUid: creatorUid,
        membersUid: {
          ...members,
          creatorUid, // 👈 creator always included
        }.toList(),
        headline: '',
      );

      ref.read(selectedCommunityMembersProvider.notifier).state = [];

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack("Failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
    
  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(selectedCommunityMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Community'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ---------------- IMAGE ----------------
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    SafeImage(
                      url: _image != null ? _image!.path : '',
                      size: 90,
                      isCircular: true,
                      borderColor: Colors.grey.shade300,
                      borderWidth: 2,
                    ),
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black87,
                      child: Icon(Icons.camera_alt,
                          size: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- NAME ----------------
              TextField(
                controller: _name,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Community name',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              // ---------------- DESC ----------------
              TextField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- MEMBERS ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Add members",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "${members.length} selected",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectContactsGroup(
                    selectionProvider: selectedCommunityMembersProvider,
                  ),

                ),
              ),

              const SizedBox(height: 16),

              // ---------------- CREATE ----------------
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  child: _loading
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      : const Text("Create Community"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
