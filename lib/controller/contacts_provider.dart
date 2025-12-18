// lib/controller/contacts_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';


/// --------------------------------------------------------------
///  CONTACT CONTROLLER
/// --------------------------------------------------------------
class ContactsController {
  final Ref ref;
  ContactsController(this.ref);

  /// Load all contacts from device
  Future<List<Contact>> loadContacts() async {
    // request permission
    if (!await FlutterContacts.requestPermission()) {
      return [];
    }

    // load contacts with thumbnails
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: true,
    );

    return contacts;
  }

  /// Filter contact list
  List<Contact> filterContacts(String query, List<Contact> contacts) {
    if (query.isEmpty) return contacts;

    return contacts.where((c) {
      final name = c.displayName.toLowerCase();
      final q = query.toLowerCase();

      final hasPhone = c.phones.isNotEmpty &&
          c.phones.first.number.replaceAll(" ", "").contains(query);

      return name.contains(q) || hasPhone;
    }).toList();
  }

  /// Start chat / invite
  void startChat(BuildContext context, Contact c) {
    final phone =
        c.phones.isNotEmpty ? c.phones.first.number : "No number found";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Chat with ${c.displayName} ($phone)")),
    );

    // TODO: Add your chat navigation logic here
  }
}

/// --------------------------------------------------------------
///  RIVERPOD PROVIDERS
/// --------------------------------------------------------------

/// Controller provider (THIS WAS MISSING)
final contactsControllerProvider =
    Provider<ContactsController>((ref) => ContactsController(ref));

/// List of all contacts
final contactsListProvider = StateProvider<List<Contact>>((ref) => []);

/// Filtered contacts
final filteredContactsProvider = StateProvider<List<Contact>>((ref) => []);

/// Search text
final searchQueryProvider = StateProvider<String>((ref) => "");
