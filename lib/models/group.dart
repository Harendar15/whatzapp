class Group {
  final String senderId;
  final String name;
  final String groupId;
  final String lastMessage;
  final String groupPic;
  final List<String> membersUid;
  final DateTime timeSent;

  /// optional
  final String? communityId;
  final bool isAnnouncementGroup;

  final Map<String, dynamic> meta;
  final String description;
  final String creatorUid;
  final List<String> admins;

  Group({
    required this.senderId,
    required this.name,
    required this.groupId,
    required this.lastMessage,
    required this.groupPic,
    required this.membersUid,
    required this.timeSent,

    /// optional fields
    this.communityId,
    this.isAnnouncementGroup = false,
    this.description = "",
    this.creatorUid = "",

    /// FIXED — initialize meta & admins safely
    Map<String, dynamic>? meta,
    List<String>? admins,
  })  : meta = meta ?? {},
        admins = admins ?? [];

  // ------------------------------------------------
  // SAVE
  // ------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'name': name,
      'groupId': groupId,
      'lastMessage': lastMessage,
      'groupPic': groupPic,
      'membersUid': membersUid,
      'timeSent': timeSent.millisecondsSinceEpoch,
      'meta': meta,
      'communityId': communityId,
      'isAnnouncementGroup': isAnnouncementGroup,
      'description': description,
      'creatorUid': creatorUid,
      'admins': admins,
    };
  }

  // ------------------------------------------------
  // LOAD
  // ------------------------------------------------
  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      senderId: map['senderId'] ?? '',
      name: map['name'] ?? '',
      groupId: map['groupId'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      groupPic: map['groupPic'] ?? '',
      membersUid: List<String>.from(map['membersUid'] ?? []),

      timeSent: (map['timeSent'] is int)
          ? DateTime.fromMillisecondsSinceEpoch(map['timeSent'])
          : DateTime.now(),

      meta: map['meta'] == null
          ? {}
          : Map<String, dynamic>.from(map['meta']),

      communityId: map['communityId'],
      isAnnouncementGroup: map['isAnnouncementGroup'] ?? false,
      description: map['description'] ?? "",
      creatorUid: map['creatorUid'] ?? "",
      admins: List<String>.from(map['admins'] ?? []),
    );
  }
}
