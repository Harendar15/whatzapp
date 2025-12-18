import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';

const String isLoggedInKey = "isLoggedInKey";
const String isCompletedKey = "isCompletedKey";
const String isUserInfoDoneKey = "isUserInfoDoneKey";

class PrefHelper {
  static final box = GetStorage();

  /// Save onboarding completion
  static Future<void> saveIntroStatus({required bool isCompleted}) async {
    await box.write(isCompletedKey, isCompleted);
    debugPrint("📝 PrefHelper.saveIntroStatus => $isCompleted");
  }

  /// Read onboarding completion
  static bool isCompleted() {
    final value = box.read(isCompletedKey) ?? false;
    debugPrint("📖 PrefHelper.isCompleted => $value");
    return value;
  }

  /// Check login state
  static bool isLoggedIn() {
    final value = box.read(isLoggedInKey) ?? false;
    debugPrint("📖 PrefHelper.isLoggedIn => $value");
    return value;
  }

  /// Save login state
  static Future<void> isLoginSuccess({required bool isLoggedIn}) async {
    await box.write(isLoggedInKey, isLoggedIn);
    debugPrint("📝 PrefHelper.isLoginSuccess => $isLoggedIn");
  }

  /// Mark user info completed
  static Future<void> setUserInfoComplete() async {
    await box.write(isUserInfoDoneKey, true);
    debugPrint("📝 PrefHelper.setUserInfoComplete => TRUE");
  }

  /// Check if user info is completed
  static bool isUserInfoComplete() {
    final value = box.read(isUserInfoDoneKey) ?? false;
    debugPrint("📖 PrefHelper.isUserInfoComplete => $value");
    return value;
  }

  /// Clear stored values
  static Future<void> logout() async {
    await box.remove(isLoggedInKey);
    await box.remove(isCompletedKey);
    await box.remove(isUserInfoDoneKey);
    debugPrint("🧹 PrefHelper.logout => cleared keys");
  }
}
