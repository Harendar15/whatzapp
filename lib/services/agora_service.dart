import 'package:cloud_functions/cloud_functions.dart';

class AgoraService {
  final HttpsCallable _getAgoraToken =
      FirebaseFunctions.instance.httpsCallable('getAgoraToken');

  final HttpsCallable _sendCallNotification =
      FirebaseFunctions.instance.httpsCallable('sendCallNotification');

      
   Future<String> getToken(String channel) async {
    final res = await _getAgoraToken.call({
      'channelName': channel,
      'uid': 0,
    });
    return res.data['token'];
  }

  /// Fetch Agora RTC Token
  Future<Map<String, dynamic>> fetchAgoraToken({
    required String channelName,
    required int uid,
  }) async {
    final result = await _getAgoraToken.call({
      'channelName': channelName,
      'uid': uid,
      'role': 'publisher',
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Send notification to target user
 Future<void> sendCallNotification({
  required String targetUid,
  required String callerName,
  required String channelName,
  required bool video,
}) async {
  final functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  await functions.httpsCallable("sendCallNotification").call({
    'targetUid': targetUid,
    'callerName': callerName,
    'channelName': channelName,
    'callType': video ? 'video' : 'audio',
  });
}

}
