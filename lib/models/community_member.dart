// lib/models/community_member.dart

/// Represents a single member in a community.
/// Useful if you later add roles, mute settings, join time, etc.

class CommunityMember {
  final String uid;
  final bool isAdmin;
  final int joinedAt;

  CommunityMember({
    required this.uid,
    required this.isAdmin,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'isAdmin': isAdmin,
      'joinedAt': joinedAt,
    };
  }

  factory CommunityMember.fromMap(Map<String, dynamic> map) {
    return CommunityMember(
      uid: map['uid'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      joinedAt: (map['joinedAt'] is int)
          ? map['joinedAt']
          : int.tryParse('${map['joinedAt']}') ?? 0,
    );
  }
}
