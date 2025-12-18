// lib/helpers/local_storage.dart
import 'package:get_storage/get_storage.dart';

class LocalStorage {
  static final GetStorage _box = GetStorage();

  // Keys
  static const String _myUidKey = 'myUid';
  static const String deviceIdKey = 'my_device_id';
  static const String _communityIdKey = 'communityId';
  static const String _langSmallKey = 'langSmall';
  static const String _langCapKey = 'langCap';
  static const String _languageNameKey = 'languageName';

  // Save & read logged-in user's UID
  static void saveMyUid(String uid) {
    _box.write(_myUidKey, uid);
  }

  static String? getMyUid() {
    return _box.read(_myUidKey);
  }

  // Save & read device id (synchronous for convenience)
  static void saveDeviceId(String id) {
    _box.write(deviceIdKey, id);
  }

  static String? getDeviceId() {
    return _box.read(deviceIdKey);
  }

  // Save & read current community ID
  static void saveCommunityId({required String id}) {
    _box.write(_communityIdKey, id);
  }

  static String getCommunityID() {
    return _box.read(_communityIdKey) ?? '';
  }

  // ------------------------
  // Language helpers (needed by LanguageController)
  // ------------------------
  static void saveLanguage({
    required String langSmall,
    required String langCap,
    required String languageName,
  }) {
    _box.write(_langSmallKey, langSmall);
    _box.write(_langCapKey, langCap);
    _box.write(_languageNameKey, languageName);
  }

  static String? getLanguageSmall() => _box.read(_langSmallKey);
  static String? getLanguageCap() => _box.read(_langCapKey);
  static String? getLanguageName() => _box.read(_languageNameKey);

  // Clear (optional helper)
  static void clearAll() {
    _box.erase();
  }
}
