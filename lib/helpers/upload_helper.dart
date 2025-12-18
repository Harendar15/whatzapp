import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'image_compress.dart';

class UploadHelper {
  static Future<String> uploadProfileImage(String uid, File file) async {
    final compressed = await ImageCompressor.compress(file);

    final ref = FirebaseStorage.instance
        .ref()
        .child("profilePic")
        .child(uid);

    await ref.putFile(compressed);
    return await ref.getDownloadURL();
  }

  static Future<String> uploadChatMedia(String chatId, File file) async {
    final compressed = await ImageCompressor.compress(file);
    final id = const Uuid().v4();

    final ref = FirebaseStorage.instance
        .ref()
        .child("chatMedia")
        .child(chatId)
        .child("$id.jpg");

    await ref.putFile(compressed);
    return await ref.getDownloadURL();
  }

  static Future<String> uploadGroupPic(String groupId, File file) async {
    final compressed = await ImageCompressor.compress(file);

    final ref = FirebaseStorage.instance
        .ref()
        .child("groupPics")
        .child("$groupId.jpg");

    await ref.putFile(compressed);
    return await ref.getDownloadURL();
  }
}
