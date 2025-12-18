import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  static Future<File> compress(File file) async {
    final outPath = "${file.path}_compressed.jpg";

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      outPath,
      quality: 70,
      format: CompressFormat.jpeg, // 🔥 force JPEG
    );

    if (result == null) {
      return file; // fallback
    }

    return File(result.path);
  }
}

