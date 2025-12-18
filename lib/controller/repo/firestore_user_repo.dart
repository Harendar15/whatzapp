import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../utils/phone_utils.dart';

class FirestoreUserRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<UserModel>> streamUniqueUsers() {
    return _firestore.collection('users').snapshots().map((snap) {
      final Map<String, UserModel> map = {};

      for (final doc in snap.docs) {
        final user = UserModel.fromMap(doc.data());
        final phone = PhoneUtils.normalize(user.phoneNumber);

        if (phone.length == 10) {
          map[phone] = user; // overwrite duplicates
        }
      }
      return map.values.toList();
    });
  }
}
