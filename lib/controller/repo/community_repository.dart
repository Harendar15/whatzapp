// lib/controller/repo/community_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/community.dart';
import 'group_repository.dart';
import 'package:adchat/helpers/local_storage.dart';
import 'package:firebase_storage/firebase_storage.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final groupRepo = ref.read(groupRepositoryProvider);

  return CommunityRepository(
    firestore: firestore,
    auth: auth,
    groupRepository: groupRepo,
  );
});

class CommunityRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final GroupRepository groupRepository;

  CommunityRepository({
    required this.firestore,
    required this.auth,
    required this.groupRepository,
  });

  User? get currentUser => auth.currentUser;

  // -------------------------------------------------
  // CREATE COMMUNITY (WhatsApp-style)
  // -------------------------------------------------
  Future<String> createCommunity({
    required String name,
    required String creatorUid,
    String description = '',
    required List<String> membersUid, 
    String headline = '',
    String imageUrl = "",
    File? communityImage,
  }) async {
       final uniqueMembers = {
            ...membersUid,
            creatorUid, // 🔒 creator always included
          }.toList();

    final String communityId = const Uuid().v1();
    if (communityImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("communityPics/$communityId.jpg");
        await ref.putFile(communityImage);
        imageUrl = await ref.getDownloadURL();
      }

    // 1) Create mandatory ANNOUNCEMENT group
    final String announcementGroupId = await groupRepository.createGroup(
      name: "$name • updates",
      membersUid: uniqueMembers,
      creatorUid: creatorUid,
      groupImage: communityImage,
      communityId: communityId,
      isAnnouncementGroup: true,
    );

 
    // TODO: upload communityImage to /communityPics and set communityPic URL
    final community = Community(
      communityId: communityId,
      name: name,
      communityPic: imageUrl,
      description: description,
      headline: headline,
      membersUid: uniqueMembers,
      groupIds: [announcementGroupId],
      admins: [creatorUid],
      announcementGroupId: announcementGroupId,
      lastMessage: '',
      timeSent: DateTime.now().millisecondsSinceEpoch,
    );
      await firestore
        .collection("community")
        .doc(communityId)
        .set(community.toMap());

    return communityId;
  }

  // -------------------------------------------------
  // UPDATE COMMUNITY FIELDS (Handles partial update)
  // -------------------------------------------------
  Future<void> updateCommunityFields({
    required String communityId,
    List<String>? membersUid,
    List<String>? groupsUid,
    List<String>? admins,
  }) async {
    await firestore.collection("community").doc(communityId).set(
      {
        if (membersUid != null) 'membersUid': membersUid,
        if (groupsUid != null) 'groupIds': groupsUid,
        if (admins != null) 'admins': admins,
      },
      SetOptions(merge: true),
    );
  }

  // -------------------------------------------------
  // DELETE COMMUNITY
  // -------------------------------------------------
  Future<void> deleteCommunity(String communityId) async {
  final doc = await firestore.collection("community").doc(communityId).get();
  if (!doc.exists) return;

  final data = doc.data()!;
  final announcementGroupId = data["announcementGroupId"];

  // 1) delete announcement group
  await firestore.collection("groups").doc(announcementGroupId).delete();

  // TODO: optionally delete subgroups as well if linked

  // 2) delete community doc
  await firestore.collection("community").doc(communityId).delete();
}


  // -------------------------------------------------
  // READ METHODS
  // -------------------------------------------------
 Stream<List<Community>> myCommunities({required String myUid}) {
  
  return firestore
      .collection('community')
      .where('membersUid', arrayContains: myUid)
      .orderBy('timeSent', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => Community.fromMap(d.data()))
            .toList(),
      );
}

  Stream<Community?> watchCommunity(String id) {
    return firestore.collection('community').doc(id).snapshots().map(
          (d) => d.exists ? Community.fromMap(d.data()!) : null,
        );
  }

  Future<Community?> getCommunityOnce(String id) async {
    final doc = await firestore.collection('community').doc(id).get();
    return doc.exists ? Community.fromMap(doc.data()!) : null;
  }

  // -------------------------------------------------
  // MEMBER MANAGEMENT
  // -------------------------------------------------
  Future<void> addMembers({
    required String communityId,
    required List<String> uidsToAdd,
  }) async {
    final ref = firestore.collection('community').doc(communityId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception("Community not found");

    final current = List<String>.from(snap['membersUid'] ?? []);

    for (final u in uidsToAdd) {
      if (!current.contains(u)) current.add(u);
    }

    await ref.update({'membersUid': current});
  }

  Future<void> removeMember({
    required String communityId,
    required String uidToRemove,
  }) async {
    final ref = firestore.collection('community').doc(communityId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception("Community not found");

    final members = List<String>.from(snap['membersUid'] ?? []);
    final admins = List<String>.from(snap['admins'] ?? []);

    members.remove(uidToRemove);
    admins.remove(uidToRemove);

    await ref.update({
      'membersUid': members,
      'admins': admins,
    });
  }

  // -------------------------------------------------
  // ADMIN MANAGEMENT
  // -------------------------------------------------
  Future<void> addAdmin({
    required String communityId,
    required String uid,
  }) async {
    final ref = firestore.collection('community').doc(communityId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception("Community not found");

    final admins = List<String>.from(snap['admins'] ?? []);
    if (!admins.contains(uid)) admins.add(uid);

    await ref.update({'admins': admins});
  }

  Future<void> removeAdmin({
    required String communityId,
    required String uid,
  }) async {
    final ref = firestore.collection('community').doc(communityId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception("Community not found");

    final admins = List<String>.from(snap['admins'] ?? []);
    admins.remove(uid);

    await ref.update({'admins': admins});
  }

  // -------------------------------------------------
  // LINK / UNLINK GROUPS
  // -------------------------------------------------
  Future<void> linkGroup({
  required String communityId,
  required String groupId,
}) async {
  final ref = firestore.collection('community').doc(communityId);
  final snap = await ref.get();
  if (!snap.exists) throw Exception("Community not found");

  final groups = List<String>.from(snap['groupIds'] ?? []);

  if (!groups.contains(groupId)) groups.add(groupId);

  await ref.update({'groupIds': groups});

  await firestore.collection("groups").doc(groupId).update({
    "communityId": communityId,
    "isAnnouncementGroup": false,
  });
}



  Future<void> unlinkGroup({
    required String communityId,
    required String groupId,
  }) async {
    final ref = firestore.collection('community').doc(communityId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception("Community not found");

    final groups = List<String>.from(snap['groupIds'] ?? []);
    groups.remove(groupId);

    await ref.update({'groupIds': groups});

    // ✅ Remove community reference from group
    await firestore.collection("groups").doc(groupId).set(
      {
        'communityId': null,
        'isAnnouncementGroup': false,
      },
      SetOptions(merge: true),
    );
  }

  // -------------------------------------------------
  // SEND ANNOUNCEMENT (E2E encrypted)
  // -------------------------------------------------
  Future<void> sendAnnouncement({
  required String communityId,
  required String text,
}) async {
  if (text.trim().isEmpty) return;

  final uid = auth.currentUser?.uid;
  if (uid == null) {
    throw Exception("User not logged in");
  }

  final deviceId = LocalStorage.getDeviceId();
  if (deviceId == null) {
    throw Exception("DeviceId missing");
  }

  final snap =
      await firestore.collection('community').doc(communityId).get();

  if (!snap.exists) {
    throw Exception("Community not found");
  }
  


  final data = snap.data();
  final announcementId = data?['announcementGroupId'] as String?;

  if (announcementId == null || announcementId.isEmpty) {
    throw Exception("Announcement group missing");
  }

  // 🔐 SEND AS GROUP MESSAGE
  await groupRepository.sendTextMessage(
    groupId: announcementId,
    message: text,
    senderName:
    auth.currentUser?.displayName ?? uid,
    senderDeviceId: deviceId, // ✅ REAL device id
  );
}

}
