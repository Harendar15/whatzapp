import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AudioMessagePlayer extends StatefulWidget {
  final String url;      // Firebase download URL
  final bool isMe;       // Whether the message is mine

  const AudioMessagePlayer({
    super.key,
    required this.url,
    required this.isMe,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isReady = false;
  bool _isPlaying = false;

  Duration _current = Duration.zero;
  Duration _total = Duration.zero;

  StreamSubscription? _sub;

  String? _localPath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _player.openPlayer();
    _isReady = true;

    // Download audio locally once → fast playback
    _localPath = await _downloadToLocal(widget.url);

    // Listen for playback position changes
    _sub = _player.onProgress!.listen((event) {
      if (!mounted) return;
      setState(() {
        _current = event.position;
        _total = event.duration;
      });
    });

    setState(() {});
  }

  Future<String> _downloadToLocal(String url) async {
    final dir = await getTemporaryDirectory();
    final filePath = "${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac";

    final bytes = await http.readBytes(Uri.parse(url));
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  Future<void> _togglePlay() async {
    if (!_isReady) return;

    if (_isPlaying) {
      await _player.pausePlayer();
      setState(() => _isPlaying = false);
      return;
    }

    await _player.startPlayer(
      fromURI: _localPath,
      codec: Codec.aacADTS,
      whenFinished: () {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _current = Duration.zero;
        });
      },
    );

    setState(() => _isPlaying = true);
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // PLAY / PAUSE BUTTON
          GestureDetector(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // SEEKBAR (Slider)
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: _current.inMilliseconds.toDouble(),
                max: _total.inMilliseconds.toDouble() == 0
                    ? 1
                    : _total.inMilliseconds.toDouble(),
                onChanged: (v) async {
                  final pos = Duration(milliseconds: v.toInt());
                  await _player.seekToPlayer(pos);
                },
              ),
            ),
          ),

          const SizedBox(width: 10),

          // TIME TEXT
          Text(
            _format(_current),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
