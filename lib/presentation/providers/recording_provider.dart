import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

enum RecordingStatus { idle, recording, paused, success, failure }

class RecordingState {
  final RecordingStatus status;
  final String? filePath;
  final Duration duration;
  final String? errorMessage;

  RecordingState({
    this.status = RecordingStatus.idle,
    this.filePath,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    String? filePath,
    Duration? duration,
    String? errorMessage,
  }) {
    return RecordingState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class RecordingNotifier extends Notifier<RecordingState> {
  @override
  RecordingState build() {
    // Listen for messages from overlay
    _initOverlayListener();
    return RecordingState();
  }

  Timer? _timer;

  void _initOverlayListener() {
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == 'stop') {
        stopRecording();
      }
    });
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.storage,
    ].request();
    
    print('Permission statuses: $statuses');
    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }

  Future<bool> requestOverlayPermission() async {
    if (await FlutterOverlayWindow.isPermissionGranted()) return true;
    return await FlutterOverlayWindow.requestPermission() ?? false;
  }

  Future<void> startRecording() async {
    print('Starting recording process...');
    try {
      final hasPermission = await requestPermissions();
      print('Permissions granted: $hasPermission');
      if (!hasPermission) {
        state = state.copyWith(
          status: RecordingStatus.failure,
          errorMessage: '필수 권한이 거부되었습니다.',
        );
        return;
      }

      print('Checking overlay permission...');
      final hasOverlayPermission = await requestOverlayPermission();
      print('Overlay permission granted: $hasOverlayPermission');
      if (!hasOverlayPermission) {
        state = state.copyWith(
          status: RecordingStatus.failure,
          errorMessage: '다른 앱 위에 그리기 권한이 필요합니다.',
        );
        return;
      }

      Directory? tempDir = await getExternalStorageDirectory();
      String path = '${tempDir!.path}/recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      print('Recording path: $path');

      print('Calling FlutterScreenRecording.startRecordScreenAndAudio...');
      bool started = await FlutterScreenRecording.startRecordScreenAndAudio(path);
      print('Recording started: $started');
      
      if (started) {
        state = state.copyWith(status: RecordingStatus.recording, duration: Duration.zero);
        _startTimer();
        
        // Show overlay
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          flag: OverlayFlag.defaultFlag,
          alignment: OverlayAlignment.centerRight,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> stopRecording() async {
    try {
      String path = await FlutterScreenRecording.stopRecordScreen;
      _stopTimer();
      
      state = state.copyWith(
        status: RecordingStatus.success,
        filePath: path,
      );
      
      // Close overlay
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(duration: state.duration + const Duration(seconds: 1));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final recordingProvider = NotifierProvider<RecordingNotifier, RecordingState>(() {
  return RecordingNotifier();
});
