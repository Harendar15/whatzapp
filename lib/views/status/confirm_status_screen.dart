// lib/views/status/confirm_status_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:adchat/controller/controller/status_controller.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import '../../utils/custom_color.dart';

class ConfirmStatusScreen extends ConsumerStatefulWidget {
  static const String routeName = '/confirm-status-screen';
  final File file;

  const ConfirmStatusScreen({super.key, required this.file});

  @override
  ConsumerState<ConfirmStatusScreen> createState() =>
      _ConfirmStatusScreenState();
}

class _ConfirmStatusScreenState extends ConsumerState<ConfirmStatusScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _uploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

Future<void> _addStatus() async {
  if (_uploading) return;
  setState(() => _uploading = true);

  try {
    final authRepo = ref.read(authRepositoryProvider);
    final me = await authRepo.getCurrentUserData();
    if (me == null) throw "User not logged in";

    final firestore = FirebaseFirestore.instance;

    // 1️⃣ MY CONTACTS
    final myContactsSnap = await firestore
        .collection('users')
        .doc(me.uid)
        .collection('contacts')
        .get();

    final myContacts =
        myContactsSnap.docs.map((d) => d.id).toSet();

    // 2️⃣ MY BLOCKED USERS
    final myBlockedSnap = await firestore
        .collection('users')
        .doc(me.uid)
        .collection('blocked')
        .get();

    final myBlocked =
        myBlockedSnap.docs.map((d) => d.id).toSet();

    // 3️⃣ MUTUAL CONTACTS (OPTIONAL)
    final List<String> mutualContacts = [];

    for (final uid in myContacts) {
      if (myBlocked.contains(uid)) continue;

      final theirContactsSnap = await firestore
          .collection('users')
          .doc(uid)
          .collection('contacts')
          .doc(me.uid)
          .get();

      if (theirContactsSnap.exists) {
        mutualContacts.add(uid);
      }
    }

    // ✅ IMPORTANT FIX:
    // Status upload NEVER fails
    final whoCanSee = <String>{
      me.uid, // owner always
      ...mutualContacts,
    }.toList();

    // 4️⃣ UPLOAD STATUS (ALWAYS)
    await ref.read(statusControllerProvider.notifier).uploadStatus(
      file: widget.file,
      caption: _captionController.text.trim(),
      whoCanSee: whoCanSee,
    );

    ref.read(statusControllerProvider.notifier).bindVisibleStatuses();
    Get.back();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Status uploaded 🎉")),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to upload status")),
    );
  } finally {
    setState(() => _uploading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Image.file(
                widget.file,
                fit: BoxFit.contain,
              ),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Add a caption...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.black.withOpacity(0.35),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (_uploading)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: CustomColor.primaryColor,
        child: _uploading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.done, color: Colors.white),
        onPressed: _uploading ? null : _addStatus,
      ),
    );
  }
}
