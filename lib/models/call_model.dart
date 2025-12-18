class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerImage;
  final String receiverId;
  final String receiverName;
  final String receiverImage;
  final String channelName;
  final String token;
  final String type; // audio | video
  final String status; // ringing | accepted | missed | ended
  final int timestamp;
  final String mediaKey;
  final List<String> members;

  CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerImage,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
    required this.channelName,
    required this.token,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.mediaKey,
    required this.members,
  });

  // 🔥 COPY WITH (REQUIRED FOR AGORA TOKEN UPDATE)
  CallModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerImage,
    String? receiverId,
    String? receiverName,
    String? receiverImage,
    String? channelName,
    String? token,
    String? type,
    String? status,
    int? timestamp,
    String? mediaKey,
    List<String>? members,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerImage: callerImage ?? this.callerImage,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverImage: receiverImage ?? this.receiverImage,
      channelName: channelName ?? this.channelName,
      token: token ?? this.token,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      mediaKey: mediaKey ?? this.mediaKey,
      members: members ?? this.members,
    );
  }

  factory CallModel.fromMap(Map<String, dynamic> map) {
    return CallModel(
      callId: map['callId'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerImage: map['callerImage'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverImage: map['receiverImage'] ?? '',
      channelName: map['channelName'] ?? '',
      token: map['token'] ?? '',
      type: map['type'] ?? 'video',
      status: map['status'] ?? 'ringing',
      timestamp: map['timestamp'] ?? 0,
      mediaKey: map['mediaKey'] ?? '',
      members: List<String>.from(map['members'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerImage': callerImage,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImage': receiverImage,
      'channelName': channelName,
      'token': token,
      'type': type,
      'status': status,
      'timestamp': timestamp,
      'mediaKey': mediaKey,
      'members': members,
    };
  }
}
