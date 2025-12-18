import 'package:permission_handler/permission_handler.dart';

Future<void> requestGalleryPermission() async {
  if (await Permission.photos.isDenied ||
      await Permission.photos.isRestricted) {
    await Permission.photos.request();
  }
}
