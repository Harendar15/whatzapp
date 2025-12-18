import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../views/chat/chat_screen.dart';

class SelectContactRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Request device contacts
  Future<List<Contact>> getContacts() async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      return await FlutterContacts.getContacts(withProperties: true);
    }
    return [];
  }

  /// Firebase users stream
  Stream<List<UserModel>> firestoreUsersStream() {
    return firestore.collection('users').snapshots().map(
          (snap) => snap.docs
              .map((d) =>
                  UserModel.fromMap(Map<String, dynamic>.from(d.data())))
              .toList(),
        );
  }

  /// Normalize phone numbers (WhatsApp style)
  String normalize(String number) {
    number = number.replaceAll(RegExp(r'[^0-9]'), '');

    if (number.startsWith("91")) number = number.substring(2);
    if (number.startsWith("0")) number = number.substring(1);

    return number;
  }

  /// ✅ MAIN LOGIC (SAFE MODIFY)
  Future<void> selectContact(
    Contact selectedContact,
    BuildContext context,
  ) async {
    try {
      final usersSnap = await firestore.collection('users').get();

      for (final doc in usersSnap.docs) {
        final user = UserModel.fromMap(doc.data());
        final dbNum = normalize(user.phoneNumber);

        for (final phone in selectedContact.phones) {
          final deviceNum = normalize(phone.number);

          final isMatch =
              deviceNum.length >= 10 &&
              dbNum.length >= 10 &&
              deviceNum.substring(deviceNum.length - 10) ==
                  dbNum.substring(dbNum.length - 10);

          if (isMatch) {
            if (context.mounted) {
              Get.to(() => ChatScreen(
                    name: user.name,
                    uid: user.uid,
                    isGroupChat: false,
                    profilePic: user.profilePic,
                    isCommunityChat: false,
                    isHideChat: false,
                  ));
            }
            return; // ✅ STOP after first match
          }
        }
      }

      /// ❌ Not registered → Invite
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This contact is not on AdChat'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read contact')),
        );
      }
    }
  }
}

/// PROVIDERS (unchanged)
final selectContactsRepositoryProvider =
    Provider<SelectContactRepository>((ref) => SelectContactRepository());

final getContactsProvider = FutureProvider<List<Contact>>((ref) async {
  return await ref.watch(selectContactsRepositoryProvider).getContacts();
});

final firestoreUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(selectContactsRepositoryProvider).firestoreUsersStream();
});
