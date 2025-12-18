// lib/helpers/file_picker_helpers.dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

Future<File?> pickImageFromGallery(BuildContext context) async {
  try {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return File(picked.path);
  } catch (e) {
    return null;
  }
}

Future<File?> pickImageFromCamera(BuildContext context) async {
  try {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return null;
    return File(picked.path);
  } catch (e) {
    return null;
  }
}

Future<File?> pickVideoFromGallery(BuildContext context) async {
  try {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return null;
    return File(picked.path);
  } catch (e) {
    return null;
  }
}
