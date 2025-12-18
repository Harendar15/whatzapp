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
  StatusState copyWith({List<Status>? statuses, bool? loading}) {
    return StatusState(
      statuses: statuses ?? this.statuses,
      loading: loading ?? this.loading,
    );
  }
}

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  final storage = ref.read(commonFirebaseStorageRepositoryProvider);
  final identity = IdentityKeyManager(firestore: FirebaseFirestore.instance);
  final media = MediaHelper();
  return StatusRepository(
    firestore: FirebaseFirestore.instance,
    storage: storage,
    identity: identity,
    media: media,
  );
});

final statusControllerProvider =
    StateNotifierProvider<StatusController, StatusState>((ref) {
  final repo = ref.read(statusRepositoryProvider);
  final authRepo = ref.read(authRepositoryProvider);
  return StatusController(ref: ref, repo: repo, authRepo: authRepo);
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

  List<Status> get statuses => state.statuses;
  bool get loading => state.loading;

  void bindVisibleStatuses() {
    _sub?.cancel();
    final myUid = authRepo.currentUid;
    if (myUid == null) {
      state = state.copyWith(statuses: []);
      return;
    }

    repo.autoDeleteOldStatusesForUser(myUid);
    state = state.copyWith(loading: true);

    _sub = repo.getVisibleStatuses(myUid).listen((list) {
      state = state.copyWith(statuses: list, loading: false);
    }, onError: (e) {
      state = state.copyWith(loading: false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

Stream<Map<String, dynamic>> viewersStreamDetailed(
  String ownerUid,
  int index,
) {
  return FirebaseFirestore.instance
      .collection('status')
      .doc(ownerUid)
      .snapshots()
      .map((doc) {
    final data = doc.data() ?? {};
    final seenBy = Map<String, dynamic>.from(data['seenBy'] ?? {});
    final viewers = Map<String, int>.from(seenBy['$index'] ?? {});
    return {
      'uids': viewers.keys.toList(),
      'times': viewers,
    };
  });
}


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

    // 🔥 FIX: if whoCanSee empty → allow all contacts
    List<String> visibilityList = whoCanSee;

    if (visibilityList.isEmpty) {
      final contactsSnap = await FirebaseFirestore.instance
          .collection('users')
          .get();

      visibilityList = contactsSnap.docs
          .map((d) => d.id)
          .where((uid) => uid != myUid)
          .toList();
    }

    final finalVisibilityList = {
      ...visibilityList,
      myUid,
    }.toList();

    await repo.uploadStatusEncrypted(
      uid: myUid,
      username: user.name,
      phoneNumber: user.phoneNumber,
      profilePic: user.profilePic,
      file: file,
      whoCanSee: finalVisibilityList,
      caption: caption,
    );
  } finally {
    state = state.copyWith(loading: false);
  }
}


  Future<File> downloadAndDecryptStatusImage({
    required String ownerUid,
    required int index,
  }) async {
    final myUid = authRepo.currentUid;
    final myDeviceId = authRepo.currentDeviceId;
    if (myUid == null) throw Exception('Not logged in');

    final doc = await FirebaseFirestore.instance.collection('status').doc(ownerUid).get();
    if (!doc.exists) throw Exception('status missing');
    final data = doc.data()!;
    final urls = List<String>.from(data['statusUrl'] ?? []);
    final keyIds = List<String>.from(data['keyIds'] ?? []);
    final contentNonces = Map<String, dynamic>.from(data['contentNonces'] ?? {});
    final mediaExts = List<String>.from(data['mediaExts'] ?? []);

    if (index >= urls.length) throw Exception('index out of range');

    final url = urls[index];
    final keyId = keyIds[index];
    final contentNonceB64 = contentNonces[keyId];
    if (contentNonceB64 == null) throw Exception('missing content nonce');

    final wrapped = await repo.fetchWrappedKeyForRecipient(
      ownerUid: ownerUid,
      recipientUid: myUid,
      deviceId: authRepo.currentDeviceId,
    );
    if (wrapped == null || wrapped['wrapped'] == null) {
      throw Exception('No wrapped key for you');
    }

final symmetricKey = await repo.identity.unwrapSymmetricKeyForMe(
  uid: myUid,
  deviceId: myDeviceId,
  wrapped: wrapped,
);


    final cipherFile = await repo.media.downloadFileFromUrlToTemp(
      url,
      outName: 'status_${ownerUid}_$keyId.enc',
    );

    final outExt = mediaExts.length > index ? mediaExts[index] : 'jpg';

    final plain = await repo.media.decryptFileWithKey(
      cipherFile: cipherFile,
      contentKey: symmetricKey,
      contentNonce: contentNonceB64,
      outExtension: outExt,
    );

    return plain;
  }

  Future<void> markAsSeen({
    required String ownerUid,
    required String viewerUid,
    required int index,
  }) async {
    final seenRef = FirebaseFirestore.instance
        .collection('status')
        .doc(ownerUid)
        .collection('views')
        .doc('$index');
    await seenRef.set({
      'viewers': FieldValue.arrayUnion([viewerUid]),
      'detail': {
        viewerUid: DateTime.now().millisecondsSinceEpoch,
      },
      'lastViewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

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

  Stream<List<String>> viewersStream(String ownerUid, int index) {
    final refViews = FirebaseFirestore.instance
        .collection('status')
        .doc(ownerUid)
        .collection('views')
        .doc('$index');
    return refViews.snapshots().map((snap) {
      if (!snap.exists) return <String>[];
      final data = snap.data()!;
      return List<String>.from(data['viewers'] ?? []);
    });
  }
}
