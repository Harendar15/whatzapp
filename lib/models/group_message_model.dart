// lib/models/group_message_model.dart

import 'message_model.dart';

class GroupMessage {
  final String messageId;
  final String groupId;
  final String senderId;
  final String senderDeviceId;
  final String senderName;
  
  /// FIXED: now using enum, not String
  final MessageModel type;

  final String ciphertext;
  final String nonce;
  final bool isSavedToGallery;

  final String fileUrl;
  final String wrappedContentKey;
  final String wrappedContentKeyNonce;
  final String contentNonce;

  final String keyId;
  final int timeSent;

  final List<dynamic> seenBy;
  final Map<String, dynamic> reactions;
  final bool edited;
  final bool deleted;
  final String mediaExt;
  final String mac;



  // Reply fields
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToTextPreview;
  final MessageModel? replyToType;

  GroupMessage({
    required this.messageId,
    required this.groupId,
    required this.senderId,
    required this.senderDeviceId,
    required this.senderName,
    required this.type,
    required this.ciphertext,
    required this.mac,
    required this.nonce,
    required this.fileUrl,
    required this.wrappedContentKey,
    required this.wrappedContentKeyNonce,
    required this.contentNonce,
    required this.keyId,
    required this.timeSent,
    required this.seenBy,
    required this.reactions,
    required this.edited,
    required this.deleted,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToTextPreview,
    this.replyToType,
    this.mediaExt = '',
    this.isSavedToGallery = false,


  });

  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    int parseTime(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();

      final s = v.toString();
      final n = int.tryParse(s);
      if (n != null) return n;

      try {
        return DateTime.parse(s).millisecondsSinceEpoch;
      } catch (_) {
        return 0;
      }
    }

    return GroupMessage(
      messageId: map['messageId'] ?? '',
      groupId: map['groupId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderDeviceId: map['senderDeviceId'] ?? '',
      senderName: map['senderName'] ?? '',
      mac: map['mac'] ?? '',

      isSavedToGallery: map['isSavedToGallery'] ?? false,

      /// FIXED: Convert string → enum
      type: (map['type']?.toString() ?? 'text').toMessageModel(),

      ciphertext: map['ciphertext'] ?? '',
      nonce: map['nonce'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      wrappedContentKey: map['wrappedContentKey'] ?? '',
      wrappedContentKeyNonce: map['wrappedContentKeyNonce'] ?? '',
      contentNonce: map['contentNonce'] ?? '',
      keyId: map['keyId'] ?? '',
      timeSent: parseTime(map['timeSent']),
      seenBy: List.from(map['seenBy'] ?? []),
      reactions: Map<String, dynamic>.from(map['reactions'] ?? {}),
      edited: map['edited'] ?? false,
      deleted: map['deleted'] ?? false,
      mediaExt: map['mediaExt'] ?? '',
      replyToMessageId: map['replyToMessageId'],
      replyToSenderName: map['replyToSenderName'],
      replyToTextPreview: map['replyToTextPreview'],
      replyToType: map['replyToType'] == null
          ? null
          : map['replyToType'].toString().toMessageModel(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'groupId': groupId,
      'senderId': senderId,
      'senderDeviceId': senderDeviceId,
      'senderName': senderName,

      /// FIXED: store enum as string
      'type': type.type,
      'isSavedToGallery': isSavedToGallery,

      'ciphertext': ciphertext,
      'nonce': nonce,
      'fileUrl': fileUrl,
      'wrappedContentKey': wrappedContentKey,
      'wrappedContentKeyNonce': wrappedContentKeyNonce,
      'contentNonce': contentNonce,
      'keyId': keyId,
      'timeSent': timeSent,
      'seenBy': seenBy,
      'reactions': reactions,
      'edited': edited,
      'deleted': deleted,
      'mediaExt': mediaExt,
      'replyToMessageId': replyToMessageId,
      'replyToSenderName': replyToSenderName,
      'replyToTextPreview': replyToTextPreview,

      /// FIXED
      'replyToType': replyToType?.type,
    };
  }
}
