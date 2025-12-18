// lib/models/community.dart

class Community {
  final String communityId;
  final String name;
  final String communityPic;
  final String description;
  final String headline;
  final List<String> membersUid;
  final List<String> groupIds; 
  final List<String> admins;         // <-- ONLY THIS NAME USED
  final String announcementGroupId;
  final String lastMessage;
  final int timeSent;

  Community({
    required this.communityId,
    required this.name,
    required this.communityPic,
    required this.description,
    required this.headline,
    required this.membersUid,
    required this.groupIds,
    required this.admins,
    required this.announcementGroupId,
    required this.lastMessage,
    required this.timeSent,
  });

  Map<String, dynamic> toMap() {
    return {
      'communityId': communityId,
      'name': name,
      'communityPic': communityPic,
      'description': description,
      'headline': headline,
      'membersUid': membersUid,
      'groupIds': groupIds,
      'admins': admins,
      'announcementGroupId': announcementGroupId,
      'lastMessage': lastMessage,
      'timeSent': timeSent,
    };
  }

  factory Community.fromMap(Map<String, dynamic> map) {
    return Community(
      communityId: map['communityId'] ?? '',
      name: map['name'] ?? '',
      communityPic: map['communityPic'] ?? '',
      description: map['description'] ?? '',
      headline: map['headline'] ?? '',
      membersUid: List<String>.from(map['membersUid'] ?? []),
      groupIds: List<String>.from(map['groupIds'] ?? []),
       admins: (map['admins'] is List)
          ? List<String>.from(map['admins'])
          : <String>[],    // FIX HERE
      announcementGroupId: map['announcementGroupId'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      timeSent: map['timeSent'] ?? 0,
    );
  }
}
