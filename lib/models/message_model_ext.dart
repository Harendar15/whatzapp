// lib/models/message_model.dart

enum MessageModel {
  text('text'),
  image('image'),
  video('video'),
  audio('audio'),
  gif('gif');

  final String type;
  const MessageModel(this.type);

  @override
  String toString() => type;
}


// ------------------------------------------------------------
//  CLEAN + UNIFIED PARSER (REPLACES message_model_ext.dart)
// ------------------------------------------------------------
extension MessageModelParser on String {
  MessageModel toMessageModel() {
    switch (toLowerCase()) {
      case 'image':
        return MessageModel.image;
      case 'video':
        return MessageModel.video;
      case 'audio':
        return MessageModel.audio;
      case 'gif':
        return MessageModel.gif;
      case 'text':
      default:
        return MessageModel.text;
    }
  }
}


// ------------------------------------------------------------
//  COMMON CHECKS
// ------------------------------------------------------------
extension MessageModelChecks on MessageModel {
  bool get isText => this == MessageModel.text;
  bool get isImage => this == MessageModel.image;
  bool get isVideo => this == MessageModel.video;
  bool get isAudio => this == MessageModel.audio;
  bool get isGif => this == MessageModel.gif;
}
