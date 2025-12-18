// lib/views/group/group_details_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../widget/custom_loader.dart';
import '../../utils/custom_color.dart';
import '../../utils/dimensions.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import  'package:adchat/crypto/identity_key_manager.dart';
import '../../controller/repo/group_repository.dart';
import '../../crypto/group_key_client.dart';

// ⭐ SAFE IMAGE LOADER
import 'package:adchat/widget/safe_image.dart';

class GroupDetailsScreen extends StatefulWidget {
  static const String routeName = '/group-details';
  final Map<String, dynamic> groupData;

  const GroupDetailsScreen({super.key, required this.groupData});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  bool isLoading = false;
  List<UserModel> userInfo = [];
  bool isAdmin = false;

  final repo = GroupRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );

  final keyClient = GroupKeyClient(firestore: FirebaseFirestore.instance);

  @override
  void initState() {
    super.initState();
    _computeIsAdmin();
    _getUserData();
  }

  void _computeIsAdmin() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() {
      isAdmin = widget.groupData['senderId'] == uid ||
          (widget.groupData['meta'] != null &&
              (widget.groupData['meta']['admins'] ?? []).contains(uid));
    });
  }

  Future<void> _getUserData() async {
    setState(() => isLoading = true);
    userInfo = [];
    try {
      final members = widget.groupData['membersUid'] ?? [];
      for (final uid in members) {
        final snap =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (!snap.exists) continue;
        userInfo.add(UserModel.fromMap(snap.data()!));
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeMember(String memberUid) async {
    if (!isAdmin) return;

    setState(() => isLoading = true);
    try {
      await repo.removeMember(widget.groupData['groupId'], memberUid);

      // Admin must rotate group key
      await repo.markNeedsRotation(widget.groupData['groupId'], true);

      Get.snackbar('Success', 'Member removed (rotation required)');
      await _getUserData();
    } catch (e) {
      debugPrint('remove member error: $e');
      Get.snackbar('Error', 'Failed to remove member');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleAdmin(String targetUid, bool makeAdmin) async {
    if (!isAdmin) return;

    setState(() => isLoading = true);
    try {
      final metaRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupData['groupId'])
          .collection('meta')
          .doc('metaDoc');

      final snap = await metaRef.get();
      final meta = snap.data() ?? {};

      final List<String> admins =
          List<String>.from(meta['admins'] ?? [widget.groupData['senderId']]);

      if (makeAdmin) {
        if (!admins.contains(targetUid)) admins.add(targetUid);
      } else {
        admins.remove(targetUid);
      }

      await metaRef.set({'admins': admins}, SetOptions(merge: true));

      Get.snackbar('Success', 'Admin updated');
      await _getUserData();
    } catch (e) {
      debugPrint('toggle admin error: $e');
      Get.snackbar('Error', 'Failed to update admin');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _rotateKeyNow() async {
  if (!isAdmin) return;

  setState(() => isLoading = true);
  try {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final members = List<String>.from(widget.groupData['membersUid'] ?? []);

    final identity =
        IdentityKeyManager(firestore: FirebaseFirestore.instance);

    final Map<String, List<String>> memberDevices = {};

    for (final uid in members) {
      final devices = await identity.fetchAllDevicePubMap(uid);
      memberDevices[uid] = devices.keys.toList();
    }

     await keyClient.rotateGroupKeyAndPush(
      groupId: widget.groupData['groupId'],
      myUid: myUid,
      member: memberDevices,
    );

    Get.snackbar('Success', 'Group key rotated!');
  } catch (e) {
    debugPrint('rotateKey error: $e');
    Get.snackbar('Error', 'Rotation failed');
  } finally {
    setState(() => isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: CustomLoader());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupData['name'] ?? 'Group'),
      ),
      body: ListView(
        children: [
          // ⭐ FIXED GROUP HEADER WITH SAFE IMAGE
          Container(
            color: CustomColor.primaryColor.withOpacity(0.6),
            padding: EdgeInsets.symmetric(vertical: Dimensions.marginSize),
            child: Column(
              children: [
                SafeImage(
                  url: widget.groupData['groupPic'],
                  size: Dimensions.radius * 12,
                ),
                const SizedBox(height: 8),

                Text(
                  widget.groupData['name'] ?? '',
                  style: TextStyle(
                    fontSize: Dimensions.largeTextSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                Text(
                  "Group - ${userInfo.length} participants",
                  style: const TextStyle(color: Colors.grey),
                ),

                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                            onPressed: _rotateKeyNow,
                            child: const Text("Rotate Key Now")),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Get.toNamed(
                              '/add-group-members',
                              arguments: {
                                'groupId': widget.groupData['groupId'],
                                'membersUid': widget.groupData['membersUid'],
                                'fetchContacts': () async {
                                  final snap = await FirebaseFirestore.instance.collection('users').get();
                                  return snap.docs.map((d) => UserModel.fromMap(d.data()!)).toList();
                                }
                              },
                            );
                          },
                          child: const Text("Add Members"),
                        ),

                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ⭐ FIXED MEMBER LIST WITH SafeImage
          ...userInfo.map(
            (u) => ListTile(
              leading: SafeImage(
                url: u.profilePic,
                size: Dimensions.radius * 4,
              ),
              title: Text(u.name),
              subtitle: Text(u.about),
              trailing: widget.groupData['senderId'] == u.uid
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text("Group Admin"),
                    )
                  : isAdmin
                      ? PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'remove') {
                              await _removeMember(u.uid);
                            } else if (v == 'promote') {
                              await _toggleAdmin(u.uid, true);
                            } else if (v == 'demote') {
                              await _toggleAdmin(u.uid, false);
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove'),
                            ),
                            PopupMenuItem(
                              value: 'promote',
                              child: Text('Promote to admin'),
                            ),
                            PopupMenuItem(
                              value: 'demote',
                              child: Text('Demote'),
                            ),
                          ],
                        )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
