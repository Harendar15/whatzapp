// lib/controller/controller/contacts_controller.dart
// Contacts Controller → Device Contacts + Check in Firestore like WhatsApp

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../models/user_model.dart';
import '../repo/select_contact_repository.dart';

final contactsControllerProvider =
    Provider<ContactsController>((ref) {
  final repo = ref.watch(selectContactsRepositoryProvider);
  return ContactsController(ref: ref, repository: repo);
});

class ContactsController {
  final Ref ref;
  final SelectContactRepository repository;

  ContactsController({
    required this.ref,
    required this.repository,
  });

  /// Fetch all mobile contacts
  Future<List<Contact>> getContacts() async {
    return await repository.getContacts();
  }

  /// Listen Firestore users (in your database)
  Stream<List<UserModel>> firestoreUsersStream() {
    return repository.firestoreUsersStream();
  }

  /// When user taps → check if WhatsApp user exists → action
  Future<void> onSelectContact(
    Contact selectedContact,
    BuildContext context,
  ) async {
    await repository.selectContact(selectedContact, context);
  }
}
