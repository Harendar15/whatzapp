import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class VideoViewWidget extends StatelessWidget {
  final int? remoteUid;
  final bool localPreview;
  final RtcEngine rtcEngine;
  final String channelId;

  const VideoViewWidget({
    super.key,
    this.remoteUid,
    this.localPreview = false,
    required this.rtcEngine,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    if (localPreview) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: rtcEngine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }

    if (remoteUid == null || remoteUid == 0) {
      return const Center(child: Text('Waiting for remote...', style: TextStyle(color: Colors.white)));
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: rtcEngine,
        canvas: VideoCanvas(uid: remoteUid!),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }
}
