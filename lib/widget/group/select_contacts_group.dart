import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../utils/phone_utils.dart';
import '../../views/group/create_group_screen.dart';

class SelectContactsGroup extends ConsumerStatefulWidget {
  final StateProvider<List<String>> selectionProvider;

  const SelectContactsGroup({
    super.key,
    required this.selectionProvider,
  });

  @override
  ConsumerState<SelectContactsGroup> createState() =>
      _SelectContactsGroupState();
}

class _SelectContactsGroupState
    extends ConsumerState<SelectContactsGroup> {
  bool _loading = true;
  final TextEditingController _search = TextEditingController();
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    final Map<String, UserModel> unique = {};

    for (final d in snap.docs) {
      final u = UserModel.fromMap(d.data());
      if (u.uid == myUid) continue;

      final phone = PhoneUtils.normalize(u.phoneNumber);
      if (phone.length == 10) {
        unique[phone] = u;
      }
    }

    _users = unique.values.toList();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(widget.selectionProvider);
    final q = _search.text.toLowerCase();

    final filtered = _users.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.phoneNumber.contains(q);
    }).toList();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: "Search",
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final u = filtered[i];
              final isSel = selected.contains(u.uid);

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      u.profilePic.isEmpty ? null : NetworkImage(u.profilePic),
                  child: u.profilePic.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(u.name),
                subtitle: Text(u.phoneNumber),
                trailing: Checkbox(
                  value: isSel,
                  onChanged: (_) {
                    ref
                        .read(widget.selectionProvider.notifier)
                        .update((s) {
                      final list = [...s];
                      isSel ? list.remove(u.uid) : list.add(u.uid);
                      return list;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
