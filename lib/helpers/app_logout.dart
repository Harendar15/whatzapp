import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../helpers/stream_manager.dart';
import '../helpers/local_storage.dart';
import '../helpers/prefs_services.dart';
import '../views/auth/login_screen.dart';

class AppLogout {
  static Future<void> logout() async {
    // 1️⃣ Stop Firestore streams
    await StreamManager.cancelAll();

    // 2️⃣ Firebase sign out
    await FirebaseAuth.instance.signOut();

    // 3️⃣ Clear local data
    await PrefHelper.logout();
    LocalStorage.clearAll();

    // 4️⃣ Navigate
    Get.offAll(() => const LoginScreen());
  }
}
