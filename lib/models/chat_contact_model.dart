// lib/models/chat_contact_model.dart

class ChatContactModel {
  final String name;
  final String profilePic;
  final String contactId;
  final DateTime timeSent;
  final String lastMessage;
  final bool isHideChat;

  ChatContactModel({
    required this.name,
    required this.profilePic,
    required this.contactId,
    required this.timeSent,
    required this.lastMessage,
    this.isHideChat = false,
  });

  ChatContactModel copyWith({
    String? name,
    String? profilePic,
    String? contactId,
    DateTime? timeSent,
    String? lastMessage,
    bool? isHideChat,
  }) {
    return ChatContactModel(
      name: name ?? this.name,
      profilePic: profilePic ?? this.profilePic,
      contactId: contactId ?? this.contactId,
      timeSent: timeSent ?? this.timeSent,
      lastMessage: lastMessage ?? this.lastMessage,
      isHideChat: isHideChat ?? this.isHideChat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'profilePic': profilePic,
      'contactId': contactId,
      // persist timeSent as epoch millis
      'timeSent': timeSent.millisecondsSinceEpoch,
      'lastMessage': lastMessage,
      'isHideChat': isHideChat,
    };
  }

  factory ChatContactModel.fromMap(Map<String, dynamic> map) {
    // Accept timeSent as int (epoch millis) or DateTime or string number
    DateTime parseTime(dynamic t) {
      if (t == null) return DateTime.now();
      if (t is int) return DateTime.fromMillisecondsSinceEpoch(t);
      if (t is DateTime) return t;
      final parsed = int.tryParse(t.toString());
      if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed);
      return DateTime.now();
    }

    return ChatContactModel(
      name: map['name']?.toString() ?? '',
      profilePic: map['profilePic']?.toString() ?? '',
      contactId: map['contactId']?.toString() ?? map['contact_id']?.toString() ?? '',
      timeSent: parseTime(map['timeSent']),
      lastMessage: map['lastMessage']?.toString() ?? '',
      isHideChat: map['isHideChat'] ?? false,
    );
  }
}
