// lib/controller/image_picker_controller.dart
import 'package:get/get.dart';

class ImagePickerController extends GetxController {
  final imagePath = ''.obs;

  void setPath(String p) => imagePath.value = p;
  void clear() => imagePath.value = '';
}
