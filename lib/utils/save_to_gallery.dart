import 'dart:io';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../models/message_model.dart';


Future<void> saveToGallery(File file, MessageModel message) async {
  if (message.isImage || message.isVideo) {
    await ImageGallerySaver.saveFile(
      file.path,
      isReturnPathOfIOS: true,
    );
  }
}

