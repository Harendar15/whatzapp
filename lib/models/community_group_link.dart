// lib/models/community_group_link.dart

class CommunityGroupLink {
  final String communityId;
  final String groupId;
  final int linkedAt;

  CommunityGroupLink({
    required this.communityId,
    required this.groupId,
    required this.linkedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'communityId': communityId,
      'groupId': groupId,
      'linkedAt': linkedAt,
    };
  }

  factory CommunityGroupLink.fromMap(Map<String, dynamic> map) {
    return CommunityGroupLink(
      communityId: map['communityId'] ?? '',
      groupId: map['groupId'] ?? '',
      linkedAt: (map['linkedAt'] is int)
          ? map['linkedAt']
          : int.tryParse('${map['linkedAt']}') ?? 0,
    );
  }
}
