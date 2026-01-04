// lib/controller/status_controller.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repo/status_repository.dart';
import '/models/status_model.dart';
import '/controller/storage/common_firebase_storage_repository.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:adchat/crypto/media_helper.dart';
import 'package:adchat/crypto/identity_key_manager.dart';

class StatusState {
  final List<Status> statuses;
  final bool loading;

  StatusState({required this.statuses, required this.loading});

  StatusState copyWith({
    List<Status>? statuses,
    bool? loading,
  }) {
    return StatusState(
      statuses: statuses ?? this.statuses,
      loading: loading ?? this.loading,
    );
  }
}

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return StatusRepository(
    firestore: FirebaseFirestore.instance,
    storage: ref.read(commonFirebaseStorageRepositoryProvider),
    identity: IdentityKeyManager(firestore: FirebaseFirestore.instance),
    media: MediaHelper(),
  );
});

final statusControllerProvider =
    StateNotifierProvider<StatusController, StatusState>((ref) {
  return StatusController(
    ref: ref,
    repo: ref.read(statusRepositoryProvider),
    authRepo: ref.read(authRepositoryProvider),
  );
});

class StatusController extends StateNotifier<StatusState> {
  final Ref ref;
  final StatusRepository repo;
  final AuthRepository authRepo;

  StreamSubscription<List<Status>>? _sub;

  StatusController({
    required this.ref,
    required this.repo,
    required this.authRepo,
  }) : super(StatusState(statuses: [], loading: false));

  // ============================================================
  // 🔄 BIND STATUS STREAM
  // ============================================================
  void bindVisibleStatuses() {
    _sub?.cancel();

    final myUid = authRepo.currentUid;
    if (myUid == null) return;

    state = state.copyWith(loading: true);

    repo.autoDeleteOldStatusesForUser(myUid);

    _sub = repo.getVisibleStatuses(myUid).listen(
      (list) {
        state = state.copyWith(statuses: list, loading: false);
      },
      onError: (_) {
        state = state.copyWith(loading: false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ============================================================
  // 👀 VIEWERS STREAM (FIXED – single source)
  // ============================================================
  Stream<Map<String, int>> viewersStream(String ownerUid, int index) {
    return FirebaseFirestore.instance
        .collection('status')
        .doc(ownerUid)
        .collection('views')
        .doc('$index')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return {};
      final data = snap.data()!;
      return Map<String, int>.from(data['detail'] ?? {});
    });
  }

  // ============================================================
  // ⬆️ UPLOAD STATUS (FORCE DEVICE REGISTRATION)
  // ============================================================
  Future<void> uploadStatus({
    required File file,
    required List<String> whoCanSee,
    String caption = '',
  }) async {
    state = state.copyWith(loading: true);
    try {
      final user = await authRepo.getCurrentUserData();
      if (user == null) throw Exception('Not logged in');

      final myUid = user.uid;
      final deviceId = authRepo.currentDeviceId;

      // 🔥 FORCE REGISTER DEVICE
      await repo.identity.loadOrCreateIdentityKey(myUid, deviceId);

     // whoCanSee = phone numbers list
        final resolvedUids =
            await repo.resolveContactUidsFromPhoneNumbers(whoCanSee);

        final visibility = {
          ...resolvedUids,
          myUid, // owner always included
        }.toList();

      await repo.uploadStatusEncrypted(
        uid: myUid,
        username: user.name,
        phoneNumber: user.phoneNumber,
        profilePic: user.profilePic,
        file: file,
        whoCanSee: visibility,
        caption: caption,
      );
    } finally {
      state = state.copyWith(loading: false);
    }
  }
  Future<List<String>> _getMyContactsUids() async {
  final myUid = authRepo.currentUid!;
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(myUid)
      .collection('contacts')
      .get();

  return snap.docs.map((d) => d.id).toList();
}

  // ============================================================
  // 🔓 DOWNLOAD + DECRYPT STATUS
  // ============================================================
  Future<File> downloadAndDecryptStatusImage({
    required String ownerUid,
    required int index,
  }) async {
    final myUid = authRepo.currentUid;
    final myDeviceId = authRepo.currentDeviceId;
    if (myUid == null) throw Exception('Not logged in');

    final doc =
        await FirebaseFirestore.instance.collection('status').doc(ownerUid).get();
    if (!doc.exists) throw Exception('Status not found');

    final data = doc.data()!;
    final urls = List<String>.from(data['statusUrl']);
    final keyIds = List<String>.from(data['keyIds']);
    final nonces = Map<String, dynamic>.from(data['contentNonces']);
    final exts = List<String>.from(data['mediaExts']);

    final wrapped = await repo.fetchWrappedKeyForRecipient(
      ownerUid: ownerUid,
      recipientUid: myUid,
      deviceId:  authRepo.currentDeviceId,
    );

    if (wrapped == null) throw Exception('No wrapped key');

    final contentKey = await repo.identity.unwrapSymmetricKeyForMe(
      uid: myUid,
      deviceId: myDeviceId,
      wrapped: wrapped,
    );

    final cipherFile = await repo.media.downloadFileFromUrlToTemp(
      urls[index],
      outName: 'status_${keyIds[index]}.enc',
    );

    return repo.media.decryptFileWithKey(
      cipherFile: cipherFile,
      contentKey: contentKey,
      contentNonce: nonces[keyIds[index]],
      outExtension: exts[index],
    );
  }
  /// 👁️ Viewers stream with timestamp (WhatsApp style)
Stream<Map<String, dynamic>> viewersStreamDetailed(
  String ownerUid,
  int index,
) {
  return FirebaseFirestore.instance
      .collection('status')
      .doc(ownerUid)
      .collection('views')
      .doc('$index')
      .snapshots()
      .map((doc) {
    if (!doc.exists) {
      return {
        'uids': <String>[],
        'times': <String, int>{},
      };
    }

    final data = doc.data()!;
    final viewers = List<String>.from(data['viewers'] ?? []);
    final detail = Map<String, int>.from(data['detail'] ?? {});

    return {
      'uids': viewers,
      'times': detail,
    };
  });
}

  // ============================================================
  // 👁 MARK AS SEEN (SINGLE SOURCE)
  // ============================================================
  Future<void> markAsSeen({
    required String ownerUid,
    required int index,
  }) async {
    final myUid = authRepo.currentUid;
    if (myUid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('status')
        .doc(ownerUid)
        .collection('views')
        .doc('$index');

    await ref.set({
      'viewers': FieldValue.arrayUnion([myUid]),
      'detail': {
        myUid: DateTime.now().millisecondsSinceEpoch,
      },
    }, SetOptions(merge: true));
  }

  // ============================================================
  // 🗑 DELETE
  // ============================================================
  Future<void> deleteSingleStatus({
    required String ownerUid,
    required int index,
  }) async {
    await repo.deleteStatusItem(ownerUid: ownerUid, index: index);
  }

  Future<void> deleteAllMyStatuses() async {
    final myUid = authRepo.currentUid;
    if (myUid == null) return;
    await repo.deleteAllStatusesOfUser(myUid);
  }
}
