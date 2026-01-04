import 'package:cloud_functions/cloud_functions.dart';

class AgoraService {
  AgoraService._();

  static final AgoraService instance = AgoraService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// 🔐 Fetch Agora RTC Token (ONLY METHOD)
  Future<String> fetchToken({
    required String channelName,
    required int uid,
  }) async {
    final result = await _functions
        .httpsCallable('getAgoraToken')
        .call({
      'channelName': channelName,
      'uid': uid,
      'role': 'publisher',
    });

    final token = result.data['token'];
    if (token == null || token.toString().isEmpty) {
      throw Exception('Agora token missing from Cloud Function');
    }

    return token;
  }

  /// 🔔 Send call push notification
  Future<void> sendCallNotification({
    required String targetUid,
    required String callerName,
    required String channelName,
    required bool video,
  }) async {
    await _functions
        .httpsCallable('sendCallNotification')
        .call({
      'targetUid': targetUid,
      'callerName': callerName,
      'channelName': channelName,
      'callType': video ? 'video' : 'audio',
    });
  }
}
