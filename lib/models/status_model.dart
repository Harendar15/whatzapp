class Status {
  final String uid;
  final String username;
  final String phoneNumber;
  final String profilePic;
  final String statusId;

  final List<String> statusUrl;
  final List<int> uploadTime;
  final List<String> keyIds;
  final List<String> mediaTypes;
  final List<String> mediaExts;
  final List<String> captions;

  /// 🔥 NEW — per media seenBy
  /// key = mediaIndex (0,1,2)
  /// value = list of user UIDs
  final Map<String, Map<String, int>> seenBy;


  final Map<String, dynamic> contentNonces;
  final List<String> whoCanSee;
  final int expiresAt;

  Status({
    required this.uid,
    required this.username,
    required this.phoneNumber,
    required this.profilePic,
    required this.statusId,
    required this.statusUrl,
    required this.uploadTime,
    required this.keyIds,
    required this.mediaTypes,
    required this.mediaExts,
    required this.captions,
    required this.seenBy,
    required this.contentNonces,
    required this.whoCanSee,
    required this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'phoneNumber': phoneNumber,
      'profilePic': profilePic,
      'statusId': statusId,
      'statusUrl': statusUrl,
      'uploadTime': uploadTime,
      'keyIds': keyIds,
      'mediaTypes': mediaTypes,
      'mediaExts': mediaExts,
      'captions': captions,
      'seenBy': seenBy,
      'contentNonces': contentNonces,
      'whoCanSee': whoCanSee,
      'expiresAt': expiresAt,
    };
  }

  factory Status.fromMap(Map<String, dynamic> map) {
    return Status(
      uid: map['uid'],
      username: map['username'],
      phoneNumber: map['phoneNumber'],
      profilePic: map['profilePic'],
      statusId: map['statusId'],
      statusUrl: List<String>.from(map['statusUrl'] ?? []),
      uploadTime: List<int>.from(map['uploadTime'] ?? []),
      keyIds: List<String>.from(map['keyIds'] ?? []),
      mediaTypes: List<String>.from(map['mediaTypes'] ?? []),
      mediaExts: List<String>.from(map['mediaExts'] ?? []),
      captions: List<String>.from(map['captions'] ?? []),
      seenBy: (map['seenBy'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(
          k,
          Map<String, int>.from(v as Map),
        ),
      ),

      contentNonces: Map<String, dynamic>.from(map['contentNonces'] ?? {}),
      whoCanSee: List<String>.from(map['whoCanSee'] ?? []),
      expiresAt: map['expiresAt'] ?? 0,
    );
  }
}
