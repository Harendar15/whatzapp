// lib/views/contacts/contacts_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controller/contacts_provider.dart';


class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(contactsControllerProvider);
    final contacts = ref.watch(contactsListProvider);
    final filtered = ref.watch(filteredContactsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Contacts"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final loaded = await controller.loadContacts();
              ref.read(contactsListProvider.notifier).state = loaded;
              ref.read(filteredContactsProvider.notifier).state = loaded;
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (text) {
                ref.read(searchQueryProvider.notifier).state = text;
                ref.read(filteredContactsProvider.notifier).state =
                    controller.filterContacts(text, contacts);
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search contacts...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "Showing results for: '$query'",
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
              ),
            ),

          // List
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text("No contacts found"))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      final phone = c.phones.isNotEmpty
                          ? c.phones.first.number
                          : "No number";

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: c.photo == null
                              ? const CircleAvatar(child: Icon(Icons.person))
                              : CircleAvatar(
                                  backgroundImage: MemoryImage(c.photo!),
                                ),
                          title: Text(c.displayName),
                          subtitle: Text(phone),
                          trailing: ElevatedButton(
                            onPressed: () => controller.startChat(context, c),
                            child: const Text("Chat / Invite"),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
