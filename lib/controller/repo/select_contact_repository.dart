import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/phone_utils.dart';
import '../../views/chat/chat_screen.dart';

class SelectContactRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// CONTACTS
  Future<List<Contact>> getContacts() async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      return FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
    }
    return [];
  }

  /// USERS (DEDUP BY PHONE)
  Stream<List<UserModel>> firestoreUsersStream() {
    return firestore.collection('users').snapshots().map((snap) {
      final Map<String, UserModel> unique = {};

      for (final d in snap.docs) {
        final u = UserModel.fromMap(d.data());
        final phone = PhoneUtils.normalize(u.phoneNumber);

        if (phone.length == 10) {
          // overwrite duplicates → last wins
          unique[phone] = u;
        }
      }

      return unique.values.toList();
    });
  }



  /// normalize → last 10 digits only
  String normalize(String n) {
    final digits = n.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// WhatsApp-like open chat
  Future<void> selectContact(Contact c, BuildContext ctx) async {
    if (c.phones.isEmpty) {
      _show(ctx, "No phone number");
      return;
    }

    final contactNums = c.phones
        .map((p) => normalize(p.number))
        .where((e) => e.length == 10)
        .toSet();

    final snap = await firestore.collection('users').get();

    for (final d in snap.docs) {
      final u = UserModel.fromMap(d.data());
      final dbNum = normalize(u.phoneNumber);

      if (contactNums.contains(dbNum)) {
        Get.to(() => ChatScreen(
              name: u.name,
              uid: u.uid,
              profilePic: u.profilePic,
              isGroupChat: false,
              isCommunityChat: false,
              isHideChat: false,
            ));
        return;
      }
    }
    _show(ctx, "User not on AdChat");
  }

  void _show(BuildContext ctx, String msg) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

final selectContactsRepositoryProvider =
    Provider((ref) => SelectContactRepository());

final getContactsProvider =
    FutureProvider((ref) => ref.read(selectContactsRepositoryProvider).getContacts());

final firestoreUsersProvider =
    StreamProvider((ref) => ref.read(selectContactsRepositoryProvider).firestoreUsersStream());
