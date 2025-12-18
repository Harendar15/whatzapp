import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adchat/models/community.dart';
import 'package:adchat/controller/community/community_controller.dart';
import 'package:adchat/helpers/local_storage.dart';
import 'package:adchat/widget/safe_image.dart';

class CommunityDetailsScreen extends ConsumerWidget {
  static const routeName = '/community-details';
  const CommunityDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = ref.read(communityControllerProvider);
    final myUid = LocalStorage.getMyUid() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Community Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => cc.deleteCommunity(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Community>>(
        stream: cc.streamSelectedCommunity(myUid),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text('No community selected or you are not a member'));
          }

          final c = snap.data!.first;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SafeImage(url: c.communityPic, size: 80),
                const SizedBox(height: 16),
                Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(c.headline),
                const SizedBox(height: 20),
                Text("Members: ${c.membersUid.length}"),
                Text("Groups: ${c.groupIds.length}"),
              ],
            ),
          );
        },
      ),
    );
  }
}
