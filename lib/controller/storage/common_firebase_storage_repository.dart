// lib/controller/storage/common_firebase_storage_repository.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final commonFirebaseStorageRepositoryProvider =
    Provider<CommonFirebaseStorageRepository>((ref) {
  return CommonFirebaseStorageRepository(
    firebaseStorage: FirebaseStorage.instance,
  );
});

class CommonFirebaseStorageRepository {
  final FirebaseStorage firebaseStorage;

  CommonFirebaseStorageRepository({required this.firebaseStorage});

  Future<String> storeFileToFirebase(String storagePath, File file) async {
    try {
      debugPrint('📤 Upload → $storagePath');

      final ref = firebaseStorage.ref().child(storagePath);
      final snapshot = await ref.putFile(file);

      final url = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Upload OK [$storagePath] → $url');
      return url;
    } catch (e) {
      debugPrint("❌ Upload Error [$storagePath] → $e");
      rethrow;
    }
  }

  Future<String> storeBytesToFirebase(String path, Uint8List bytes) async {
    try {
      debugPrint('📤 Bytes Upload → $path');
      final ref = firebaseStorage.ref().child(path);
      final snapshot = await ref.putData(bytes);
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Bytes Upload OK [$path] → $url');
      return url;
    } catch (e) {
      debugPrint("❌ Bytes Upload Error [$path] → $e");
      rethrow;
    }
  }

  Future<String> uploadProfilePicture(String uid, File file) {
    return storeFileToFirebase("profilePics/$uid/profile.jpg", file);
  }

  Future<String> uploadChatMedia(String chatId, File file) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return storeFileToFirebase("chatMedia/$chatId/$ts", file);
  }

  Future<String> uploadStatus(String uid, File file) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return storeFileToFirebase("status/$uid/$ts.jpg", file);
  }

  Future<String> uploadGroupImage(String groupId, File file) {
    return storeFileToFirebase("groups/$groupId/groupPic.jpg", file);
  }

  Future<String> uploadCommunityImage(String communityId, File file) {
    return storeFileToFirebase("communityPics/$communityId/community.jpg", file);
  }
}
