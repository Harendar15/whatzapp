import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:adchat/controller/repo/call_repository.dart';
import 'package:adchat/controller/call/call_controller.dart';
import 'package:adchat/controller/call/call_history_controller.dart';
import 'package:adchat/models/user_model.dart';
import 'package:adchat/models/call_model.dart';
import 'package:adchat/widget/safe_image.dart';

class SelectContactForCallScreen extends StatefulWidget {
  static const String routeName = '/select-contact-for-call';
  const SelectContactForCallScreen({super.key});

  @override
  State<SelectContactForCallScreen> createState() =>
      _SelectContactForCallScreenState();
}

class _SelectContactForCallScreenState
    extends State<SelectContactForCallScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final history = Get.find<CallHistoryController>();
    final me = FirebaseAuth.instance.currentUser!;
    final q = _search.text.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select contact'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search name or number",
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: history.getContactList(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snap.data!
              .where((u) =>
                  u.name.toLowerCase().contains(q) ||
                  u.phoneNumber.contains(q))
              .toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              final channel =
                  '${me.uid}_${u.uid}_${DateTime.now().millisecondsSinceEpoch}';

              return ListTile(
                leading: SafeImage(url: u.profilePic, size: 40),
                title: Text(u.name),
                subtitle: Text(u.phoneNumber),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () async {
                    final repo = CallRepository();

                    final encryptedCall = await repo.createEncryptedCall(
                      model: CallModel(
                        callId: DateTime.now().millisecondsSinceEpoch.toString(),
                        callerId: me.uid,
                        callerName: me.phoneNumber ?? 'Me',
                        callerImage: '',
                        receiverId: u.uid,
                        receiverName: u.name,
                        receiverImage: u.profilePic,

                        channelName: me.uid.compareTo(u.uid) < 0
                            ? '${me.uid}_${u.uid}'
                            : '${u.uid}_${me.uid}',

                        token: '',
                        type: 'audio',
                        status: 'ringing',
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                        mediaKey: '',
                        members: [me.uid, u.uid],
                      ),
                    );

                    // ✅ ONLY NAVIGATE
                    Get.toNamed(
                      '/outgoing-call',
                      arguments: encryptedCall.toMap(),
                    );
                  },
                ),


               IconButton(
                      icon: const Icon(Icons.videocam),
                      onPressed: () async {
                        final repo = CallRepository();

                        final encryptedCall = await repo.createEncryptedCall(
                          model: CallModel(
                            callId: DateTime.now().millisecondsSinceEpoch.toString(),
                            callerId: me.uid,
                            callerName: me.phoneNumber ?? 'Me',
                            callerImage: '',
                            receiverId: u.uid,
                            receiverName: u.name,
                            receiverImage: u.profilePic,

                            channelName: me.uid.compareTo(u.uid) < 0
                                ? '${me.uid}_${u.uid}'
                                : '${u.uid}_${me.uid}',

                            token: '',
                            type: 'video',
                            status: 'ringing',
                            timestamp: DateTime.now().millisecondsSinceEpoch,
                            mediaKey: '',
                            members: [me.uid, u.uid],
                          ),
                        );

                        // ✅ ONLY NAVIGATE
                        Get.toNamed(
                          '/outgoing-call',
                          arguments: encryptedCall.toMap(),
                        );
                      },
                    ),


                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
