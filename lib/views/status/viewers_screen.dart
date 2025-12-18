// lib/views/status/viewers_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adchat/controller/controller/status_controller.dart';
import 'package:adchat/widget/safe_image.dart';

class ViewersScreen extends ConsumerWidget {
  final String ownerUid;
  final int index;

  const ViewersScreen({super.key, required this.ownerUid, required this.index});

  Future<Map<String, dynamic>?> _loadUser(String uid) async {
    final snap = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    return snap.data();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(statusControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Viewed by')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: ctrl.viewersStreamDetailed(ownerUid, index),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          final viewers = List<String>.from(data["uids"]);
          final times = Map<String, int>.from(data["times"]);

          if (viewers.isEmpty) return const Center(child: Text('No viewers yet'));

          return ListView.separated(
            itemCount: viewers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final uid = viewers[i];
              final viewedAt = DateTime.fromMillisecondsSinceEpoch(times[uid] ?? 0);
              return FutureBuilder<Map<String, dynamic>?>(
                future: _loadUser(uid),
                builder: (_, snapUser) {
                  final user = snapUser.data;
                  final name = user?["name"] ?? uid;
                  final pic = user?["profilePic"] ?? "https://cdn-icons-png.flaticon.com/512/149/149071.png";
                  return ListTile(
                    leading: SafeImage(url: pic, size: 45),
                    title: Text(name),
                    subtitle: Text("Viewed at ${viewedAt.hour.toString().padLeft(2,'0')}:${viewedAt.minute.toString().padLeft(2,'0')}"),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
