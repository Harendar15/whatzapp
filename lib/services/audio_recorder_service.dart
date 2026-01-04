import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  String? _recordedFilePath;
  bool _isRecording = false;

  // ---------------------------------------------
  // INIT (PERMISSION ONLY)
  // ---------------------------------------------
  Future<void> initRecorder() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission not granted');
    }
  }

  // ---------------------------------------------
  // START RECORDING (PATH GENERATION)
  // ---------------------------------------------
  Future<String> startRecording() async {
    if (_isRecording) return _recordedFilePath!;

    await initRecorder();

    final dir = await getTemporaryDirectory();
    _recordedFilePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

    // 🔴 REAL recording will be handled by platform / future plugin
    _isRecording = true;

    return _recordedFilePath!;
  }

  // ---------------------------------------------
  // STOP RECORDING
  // ---------------------------------------------
  Future<File?> stopRecording() async {
    if (!_isRecording || _recordedFilePath == null) return null;

    _isRecording = false;
    return File(_recordedFilePath!);
  }

  // ---------------------------------------------
  // DISPOSE
  // ---------------------------------------------
  void disposeRecorder() {
    _isRecording = false;
    _recordedFilePath = null;
  }
}
