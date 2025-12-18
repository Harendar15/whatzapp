import 'package:get/get.dart';

import '../../helpers/local_storage.dart';
import '../../utils/constants.dart';
import '../../utils/language/english.dart';
import '../../utils/strings.dart';

class LanguageController extends GetxController {
  var selectedLanguage = "".obs;
  @override
  void onInit() {
    selectedLanguage.value = languageStateName;
    super.onInit();
  }

  onChangeLanguage(var language, int index) {
    selectedLanguage.value = language;
    if (index == 0) {
      LocalStorage.saveLanguage(
        langSmall: 'en',
        langCap: 'US',
        languageName: English.english,
      );
      languageStateName = English.english;
    } else if (index == 1) {
      LocalStorage.saveLanguage(
        langSmall: 'id',
        langCap: 'ID',
        languageName: English.indonesian,
      );
      languageStateName = English.indonesian;
    }
  }

  final List<String> moreList = [
    Strings.english,
    Strings.indonesian,
  ];
}
