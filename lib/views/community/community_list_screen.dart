import 'package:adchat/controller/repo/community_repository.dart';
import 'package:adchat/models/community.dart';
import 'package:adchat/views/community/community_screen.dart';
import 'package:adchat/views/community/community_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:adchat/helpers/local_storage.dart';
import 'package:adchat/widget/safe_image.dart';

class CommunityListScreen extends ConsumerWidget {
  const CommunityListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(communityRepositoryProvider);
    final myUid = LocalStorage.getMyUid() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
      ),
      body: StreamBuilder<List<Community>>(
        stream: repo.myCommunities(myUid: myUid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final communities = snap.data ?? [];
          if (communities.isEmpty) {
            return const Center(child: Text('No communities yet'));
          }

          return ListView.builder(
            itemCount: communities.length,
            itemBuilder: (ctx, i) {
              final c = communities[i];
              final time = DateTime.fromMillisecondsSinceEpoch(c.timeSent);
              final timeStr = DateFormat.yMMMd().add_jm().format(time);

              return ListTile(
                leading: SafeImage(url: c.communityPic, size: 50),
                title: Text(c.name),
                subtitle: Text(
                  c.lastMessage.isEmpty ? c.description : c.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeStr, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 10),

                    // ⭐ THREE DOT MENU BUTTON
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                   onSelected: (value) {
                        if (value == "info") {
                          LocalStorage.saveCommunityId(id: c.communityId);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CommunityDetailsScreen(),
                            ),
                          );
                        }
                      },

                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: "info",
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 20),
                              SizedBox(width: 10),
                              Text("View Info"),
                            ],
                          ),
                        ),

                        // ⭐ Ready for future:
                        // PopupMenuItem(
                        //   value: "leave",
                        //   child: Row(
                        //     children: [
                        //       Icon(Icons.logout, size: 20),
                        //       SizedBox(width: 10),
                        //       Text("Leave Community"),
                        //     ],
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),

                // NORMAL TAP → Open Community Chat Home
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityScreen(communityId: c.communityId),
                    ),
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
