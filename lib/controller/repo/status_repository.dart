// lib/repo/status_repository.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

import '/models/status_model.dart';
import '/crypto/media_helper.dart';
import '/crypto/identity_key_manager.dart';
import '/controller/storage/common_firebase_storage_repository.dart';

class StatusRepository {
  final FirebaseFirestore _firestore;
  final CommonFirebaseStorageRepository _storage;
  final IdentityKeyManager identity;
  final MediaHelper media;

  StatusRepository({
    FirebaseFirestore? firestore,
    CommonFirebaseStorageRepository? storage,
    IdentityKeyManager? identity,
    MediaHelper? media,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ??
            CommonFirebaseStorageRepository(
                firebaseStorage: FirebaseStorage.instance),
        identity = identity ?? IdentityKeyManager(firestore: FirebaseFirestore.instance),
        media = media ?? MediaHelper();

  // compress helpers
  Future<File> compressImage(File file) async {
    final outPath = "${file.path}_c.jpg";
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      outPath,
      quality: 65,
      minWidth: 1080,
      minHeight: 1920,
    );
    return result != null ? File(result.path) : file;
  }

  Future<File> compressVideo(File file) async {
    return file; // placeholder - you can add video compression if needed
  }

  Future<File> autoCompress(File file) async {
    final ext = file.path.toLowerCase();
    if (ext.endsWith(".jpg") ||
        ext.endsWith(".jpeg") ||
        ext.endsWith(".png") ||
        ext.endsWith(".heic") ||
        ext.endsWith(".webp")) {
      return await compressImage(file);
    }
    if (ext.endsWith(".mp4") || ext.endsWith(".mov")) {
      return await compressVideo(file);
    }
    return file;
  }

  // delete single status item (index)
  Future<void> deleteStatusItem({
    required String ownerUid,
    required int index,
  }) async {
    final docRef = _firestore.collection('status').doc(ownerUid);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;
    final data = docSnap.data()!;
    final urls = List<String>.from(data['statusUrl'] ?? []);
    final uploadTime = List<int>.from(data['uploadTime'] ?? []);
    final keyIds = List<String>.from(data['keyIds'] ?? []);
    final mediaTypes = List<String>.from(data['mediaTypes'] ?? []);
    final mediaExts = List<String>.from(data['mediaExts'] ?? []);
    final captions = List<String>.from(data['captions'] ?? []);
    final contentNonces = Map<String, dynamic>.from(data['contentNonces'] ?? {});

    if (index < 0 || index >= urls.length) return;

    final String urlToDelete = urls[index];
    final String keyIdToDelete = keyIds.length > index ? keyIds[index] : '';

    // delete storage file (best-effort)
    try {
      final ref = FirebaseStorage.instance.refFromURL(urlToDelete);
      await ref.delete();
    } catch (_) {}

    // remove from arrays
    urls.removeAt(index);
    if (uploadTime.length > index) uploadTime.removeAt(index);
    if (keyIds.length > index) keyIds.removeAt(index);
    if (mediaTypes.length > index) mediaTypes.removeAt(index);
    if (mediaExts.length > index) mediaExts.removeAt(index);
    if (captions.length > index) captions.removeAt(index);
    contentNonces.remove(keyIdToDelete);

    if (urls.isEmpty) {
      await _deleteStatusDocAndSubcollections(ownerUid);
      return;
    }

    // update doc
    await docRef.update({
      'statusUrl': urls,
      'uploadTime': uploadTime,
      'keyIds': keyIds,
      'mediaTypes': mediaTypes,
      'mediaExts': mediaExts,
      'captions': captions,
      'contentNonces': contentNonces,
    });

    // reindex views (best-effort)
    final viewsCol = docRef.collection('views');
    final fresh = await viewsCol.get();
    final docs = fresh.docs.where((d) => int.tryParse(d.id) != null).toList()
      ..sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));

    List<WriteBatch> batches = [];
    WriteBatch currentBatch = _firestore.batch();
    int writes = 0;

    for (int i = 0; i < docs.length; i++) {
      final qdoc = docs[i];
      final desiredRef = viewsCol.doc('$i');
      currentBatch.set(desiredRef, qdoc.data());
      writes++;
      if (qdoc.id != '$i') {
        currentBatch.delete(qdoc.reference);
        writes++;
      }
      if (writes >= 400) {
        batches.add(currentBatch);
        currentBatch = _firestore.batch();
        writes = 0;
      }
    }
    batches.add(currentBatch);

    for (final b in batches) {
      try {
        await b.commit();
      } catch (_) {}
    }
  }

  Future<void> deleteAllStatusesOfUser(String ownerUid) async {
    final docRef = _firestore.collection('status').doc(ownerUid);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;
    final data = docSnap.data()!;
    final urls = List<String>.from(data['statusUrl'] ?? []);
    for (final u in urls) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(u);
        await ref.delete();
      } catch (_) {}
    }
    await _deleteStatusDocAndSubcollections(ownerUid);
  }

Future<void> _deleteStatusDocAndSubcollections(String ownerUid) async {
  try {
    final docRef = _firestore.collection('status').doc(ownerUid);

    final keysCol = docRef.collection('keys');
    final keysSnap = await keysCol.get();

    for (final k in keysSnap.docs) {
      final devicesCol = k.reference.collection('devices');
      final devSnap = await devicesCol.get();

      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (final dev in devSnap.docs) {
        batch.delete(dev.reference);
        count++;

        if (count >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }

      if (count > 0) await batch.commit();
      await k.reference.delete();
    }

    await docRef.delete();
  } on FirebaseException catch (e) {
   
  } catch (e) {
   
  }
}


  // fetch visible statuses as stream
  Stream<List<Status>> getVisibleStatuses(String myUid) {
  return _firestore
      .collection('status')
      .where('whoCanSee', arrayContains: myUid)
      .snapshots()
      .asyncMap((snap) async {
        final firestore = FirebaseFirestore.instance;

        // my blocked list
        final myBlockedSnap = await firestore
            .collection('users')
            .doc(myUid)
            .collection('blocked')
            .get();

        final myBlocked =
            myBlockedSnap.docs.map((d) => d.id).toSet();

        List<Status> visible = [];

        for (final d in snap.docs) {
          final status = Status.fromMap(d.data());
          final ownerUid = status.uid;

          // if I blocked owner → skip
          if (myBlocked.contains(ownerUid)) continue;

          // if owner blocked me → skip
          final blockedByOwner = await firestore
              .collection('users')
              .doc(ownerUid)
              .collection('blocked')
              .doc(myUid)
              .get();

          if (blockedByOwner.exists) continue;

          visible.add(status);
        }

        return visible;
      });
}


  

  Future<void> autoDeleteOldStatusesForUser(String ownerUid) async {
  try {
    final now = DateTime.now().millisecondsSinceEpoch;
    final docRef = _firestore.collection("status").doc(ownerUid);

    final doc = await docRef.get(
      const GetOptions(source: Source.serverAndCache),
    );

    if (!doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    final uploads = List<int>.from(data["uploadTime"] ?? []);
    final urls = List<String>.from(data["statusUrl"] ?? []);
    final keys = List<String>.from(data["keyIds"] ?? []);
    final mediaTypes = List<String>.from(data["mediaTypes"] ?? []);
    final mediaExts = List<String>.from(data["mediaExts"] ?? []);
    final captions = List<String>.from(data["captions"] ?? []);

    List<int> keepTimes = [];
    List<String> keepUrls = [];
    List<String> keepKeys = [];
    List<String> keepTypes = [];
    List<String> keepExts = [];
    List<String> keepCaptions = [];

    for (int i = 0; i < uploads.length; i++) {
      final age = now - uploads[i];

      if (age < 24 * 60 * 60 * 1000) {
        keepTimes.add(uploads[i]);
        keepUrls.add(urls[i]);
        keepKeys.add(keys.length > i ? keys[i] : '');
        keepTypes.add(mediaTypes.length > i ? mediaTypes[i] : 'image');
        keepExts.add(mediaExts.length > i ? mediaExts[i] : 'jpg');
        keepCaptions.add(captions.length > i ? captions[i] : '');
      } else {
        // delete expired media (best effort)
        try {
          await FirebaseStorage.instance.refFromURL(urls[i]).delete();
        } catch (_) {}
      }
    }

    if (keepUrls.isEmpty) {
      await _deleteStatusDocAndSubcollections(ownerUid);
      return;
    }

    await docRef.update({
      "uploadTime": keepTimes,
      "statusUrl": keepUrls,
      "keyIds": keepKeys,
      "mediaTypes": keepTypes,
      "mediaExts": keepExts,
      "captions": keepCaptions,
    });
  } on FirebaseException catch (e) {
    if (e.code == 'unavailable') {
      
    }
  
  } catch (e) {
    
}
  }



  // upload encrypted status
  Future<void> uploadStatusEncrypted({
    required String uid,
    required String username,
    required String phoneNumber,
    required String profilePic,
    required File file,
    required List<String> whoCanSee,
    String caption = '',
  }) async {
    final statusRef = _firestore.collection('status').doc(uid);
    final compressed = await autoCompress(file);
    final originalPath = file.path.toLowerCase();
    String mediaType = 'image';
    String outExt = 'jpg';
    if (originalPath.endsWith('.mp4') || originalPath.endsWith('.mov')) {
      mediaType = 'video';
      outExt = 'mp4';
    }

    final keyId = const Uuid().v1();
    final contentKey = await media.generateRandomContentKey();

    final enc = await media.encryptFileWithKey(
      file: compressed,
      contentKey: contentKey,
    );

    final cipherFile = enc['cipherFile'] as File;
    final contentNonceB64 = enc['contentNonce'] as String;
    final storagePath = "status/$uid/$keyId.enc";
    final downloadUrl = await _storage.storeFileToFirebase(
      storagePath,
      cipherFile,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;

    // wrap key for recipients (per device)
    for (final rUid in whoCanSee) {
      final devices = await identity.fetchAllDevicePubMap(rUid);
      if (devices.isEmpty) {
        await statusRef.collection('keys').doc(rUid).set({
          "status": "pending",
          "keyId": keyId,
          "createdAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        continue;
      }

      for (final entry in devices.entries) {
        final deviceId = entry.key;
        final devicePub = entry.value;
        final wrapped = await identity.wrapSymmetricKeyForRecipient(
          symmetricKey: contentKey,
          recipientDevicePubB64: devicePub,
        );

        await statusRef
            .collection('keys')
            .doc(rUid)
            .collection('devices')
            .doc(deviceId)
            .set({
          "status": "ok",
          "keyId": keyId,
          "wrapped": wrapped["wrapped"],
          "nonce": wrapped["nonce"],
          "ephemeralPub": wrapped["ephemeralPub"],
          "createdAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // write doc in transaction (append or create)
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(statusRef);
      if (!snap.exists) {
        final s = Status(
          uid: uid,
          username: username,
          phoneNumber: phoneNumber,
          profilePic: profilePic,
          statusId: uid,
          statusUrl: [downloadUrl],
          uploadTime: [now],
          whoCanSee: whoCanSee,
          expiresAt: expiresAt,
          keyIds: [keyId],
          contentNonces: {keyId: contentNonceB64},
          mediaTypes: [mediaType],
          mediaExts: [outExt],
          captions: [caption],
          seenBy: {
    "0": {uid: DateTime.now().millisecondsSinceEpoch},
  },
        );
        tx.set(statusRef, s.toMap());
        return;
      }

      final data = snap.data()!;
      final urls = List<String>.from(data["statusUrl"] ?? []);
      final times = List<int>.from(data["uploadTime"] ?? []);
      final keyIds = List<String>.from(data["keyIds"] ?? []);
      final contentNonces = Map<String, dynamic>.from(data["contentNonces"] ?? {});
      final existingWho = List<String>.from(data["whoCanSee"] ?? []);
      final mediaTypes = List<String>.from(data["mediaTypes"] ?? []);
      final mediaExts = List<String>.from(data["mediaExts"] ?? []);
      final captions = List<String>.from(data["captions"] ?? []);

      urls.add(downloadUrl);
      times.add(now);
      keyIds.add(keyId);
      contentNonces[keyId] = contentNonceB64;
      mediaTypes.add(mediaType);
      mediaExts.add(outExt);
      captions.add(caption);

      final mergedRecipients = <String>{}..addAll(existingWho)..addAll(whoCanSee);

     final seenBy =
    Map<String, dynamic>.from(data['seenBy'] ?? {});

      final newIndex = (urls.length - 1).toString();
        seenBy[newIndex] = {
          uid: DateTime.now().millisecondsSinceEpoch,
        };
// owner auto seen
      
      tx.update(statusRef, {
        "statusUrl": urls,
        "uploadTime": times,
        "keyIds": keyIds,
        "contentNonces": contentNonces,
        "mediaTypes": mediaTypes,
        "mediaExts": mediaExts,
        "captions": captions,
        "whoCanSee": mergedRecipients.toList(),
        "seenBy": seenBy,
      });

    });
  }
  Future<List<String>> resolveContactUidsFromPhoneNumbers(
  List<String> phoneNumbers,
) async {
  if (phoneNumbers.isEmpty) return [];

  final snap = await _firestore
      .collection('users')
      .where('phoneNumber', whereIn: phoneNumbers)
      .get();

  return snap.docs.map((d) => d.id).toList();
}

  Future<void> markStatusSeen({
  required String ownerUid,
  required int mediaIndex,
  required String viewerUid,
}) async {
  try {
    if (ownerUid == viewerUid) return;

    final ref = _firestore.collection('status').doc(ownerUid);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) return;

    final data = snap.data()!;
    final seenBy = Map<String, dynamic>.from(data['seenBy'] ?? {});
    final key = mediaIndex.toString();
    final viewers = Map<String, int>.from(seenBy[key] ?? {});

    if (viewers.containsKey(viewerUid)) return;

    viewers[viewerUid] = DateTime.now().millisecondsSinceEpoch;
    seenBy[key] = viewers;

    await ref.update({'seenBy': seenBy});
  } catch (_) {
    // silent fail – no crash
  }
}


  Future<Map<String, dynamic>?> fetchWrappedKeyForRecipient({
    required String ownerUid,
    required String recipientUid,
    required String deviceId,
  }) async {
    final doc = await _firestore
        .collection("status")
        .doc(ownerUid)
        .collection("keys")
        .doc(recipientUid)
        .collection('devices')
        .doc(deviceId)
        .get();

    return doc.data();
  }
}
