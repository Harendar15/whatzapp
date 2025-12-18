import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';

import '../../models/user_model.dart';
import '../../widget/custom_loader.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../controller/repo/select_contact_repository.dart';
import '../../widget/safe_image.dart';
import '../../router.dart';

class SelectContactsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/select-contact';
  const SelectContactsScreen({super.key});

  @override
  ConsumerState<SelectContactsScreen> createState() =>
      _SelectContactsScreenState();
}

class _SelectContactsScreenState
    extends ConsumerState<SelectContactsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

 String _normalize(String? number) {
  if (number == null || number.isEmpty) return '';
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 10) {
    return digits.substring(digits.length - 10);
  }
  return '';
}

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(getContactsProvider).when(
      loading: () =>
          const Scaffold(body: Center(child: CustomLoader())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(e.toString()))),
      data: (contactList) {
        return ref.watch(firestoreUsersProvider).when(
          loading: () =>
              const Scaffold(body: Center(child: CustomLoader())),
          error: (e, _) =>
              Scaffold(body: Center(child: Text(e.toString()))),
          data: (firebaseUsers) {
            /// 🔥 UNIQUE USERS BY PHONE
            final Map<String, UserModel> phoneUserMap = {};
           for (final u in firebaseUsers) {
        final phone = _normalize(u.phoneNumber);

        if (phone.isNotEmpty && phone.length == 10) {
          phoneUserMap[phone] = u;
        } else {
          debugPrint('❌ Firebase user skipped (invalid phone): ${u.uid}');
        }
      }


          final Map<String, UserModel> matchedUserMap = {};

            final List<Contact> localOnly = [];

            for (final c in contactList) {
              bool found = false;
              for (final p in c.phones) {
                final phone = _normalize(p.number);
                  if (phoneUserMap.containsKey(phone)) {
                final user = phoneUserMap[phone]!;
                matchedUserMap[user.uid] = user;
                found = true;
                break;
              }
            


              }
              if (!found) localOnly.add(c);
            }
              final matchedUsers = matchedUserMap.values.toList();
            final q = _query.toLowerCase();
            final filteredMatched = matchedUsers
                .where((u) =>
                    u.name.toLowerCase().contains(q) ||
                    _normalize(u.phoneNumber).contains(_normalize(q))

)
                .toList();

            final filteredLocal = localOnly
                .where((c) =>
                    c.displayName.toLowerCase().contains(q) ||
                    c.phones.any((p) =>
                        p.number.replaceAll(' ', '').contains(q)))
                .toList();

            return Scaffold(
              appBar: AppBar(
                title: Text(Strings.selectContact.tr),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search name or number',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              body: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.group_add, color: Colors.white),
                    ),
                    title: const Text(
                      "Create Group",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Get.toNamed('/create-group-screen'),
                  ),

                  /// APP USERS
                  if (filteredMatched.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredMatched.length,
                        itemBuilder: (_, i) {
                          final u = filteredMatched[i];
                          return ListTile(
                            leading: SafeImage(
                              url: u.profilePic,
                              size: Dimensions.radius * 4,
                            ),
                            title: Text(u.name),
                            subtitle: Text(u.about),
                            onTap: () {
                              AppRoutes.moveToChat({
                                'name': u.name,
                                'uid': u.uid,
                                'profilePic': u.profilePic,
                                'isGroupChat': false,
                                'isCommunityChat': false,
                                'isHideChat': false,
                              });
                            },
                          );
                        },
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(Strings.inviteTo.tr),
                  ),

                  /// LOCAL CONTACTS
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredLocal.length,
                      itemBuilder: (_, i) {
                        final c = filteredLocal[i];
                        final phone = c.phones.isNotEmpty
                            ? c.phones.first.number
                            : '';
                        return ListTile(
                          leading: c.photo == null
                              ? const CircleAvatar(child: Icon(Icons.person))
                              : CircleAvatar(
                                  backgroundImage: MemoryImage(c.photo!),
                                ),
                          title: Text(c.displayName),
                          subtitle: Text(phone),
                          trailing: ElevatedButton(
                            child: const Text("Invite"),
                            onPressed: () => _showInviteOptions(context, c),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static void _showInviteOptions(
      BuildContext context, Contact contact) {
    final phone =
        contact.phones.isNotEmpty ? contact.phones.first.number : '';

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text("Invite via SMS"),
              onTap: () async {
                Navigator.pop(context);
                final msg =
                    "Join me on AdChat 🔐\nhttps://play.google.com/store/apps/details?id=com.example.adchat";
                final uri = Uri.parse(
                    "sms:$phone?body=${Uri.encodeComponent(msg)}");
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text("Share link"),
              onTap: () {
                Navigator.pop(context);
                Share.share(
                  "Join me on AdChat 🔐\nhttps://play.google.com/store/apps/details?id=com.example.adchat",
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
