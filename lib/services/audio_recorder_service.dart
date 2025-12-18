import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderService {
  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;

  String? recordedFilePath;

  AudioRecorderService() {
    _recorder = FlutterSoundRecorder();
  }

  // ---------------------------------------------
  // INIT RECORDER
  // ---------------------------------------------
  Future<void> initRecorder() async {
    // Request permissions
    await Permission.microphone.request();

    if (_recorder!.isStopped) {
      await _recorder!.openRecorder();
    }

    _isRecorderInitialized = true;
  }

  // ---------------------------------------------
  // START RECORDING
  // ---------------------------------------------
  Future<String?> startRecording() async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }

    Directory appDir = await getApplicationDocumentsDirectory();

    recordedFilePath =
        "${appDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac";

    await _recorder!.startRecorder(
      toFile: recordedFilePath,
      codec: Codec.aacMP4,
    );

    return recordedFilePath;
  }

  // ---------------------------------------------
  // STOP RECORDING
  // ---------------------------------------------
  Future<String?> stopRecording() async {
    if (!_isRecorderInitialized) return null;

    await _recorder!.stopRecorder();
    return recordedFilePath;
  }

  // ---------------------------------------------
  // DISPOSE
  // ---------------------------------------------
  Future<void> disposeRecorder() async {
    await _recorder!.closeRecorder();
    _isRecorderInitialized = false;
  }
}
