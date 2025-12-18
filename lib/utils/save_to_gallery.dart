import 'dart:io';
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../models/message_model.dart';

Future<void> saveToGallery(File file, MessageModel type) async {
  if (type.isImage) {
    await GallerySaver.saveImage(file.path);
  } else if (type.isVideo) {
    await GallerySaver.saveVideo(file.path);
  }
}
