import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:smartphone_recorder/presentation/providers/gallery_provider.dart';

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

      print('Calling FlutterScreenRecording.startRecordScreenAndAudio...');
      // Note: The plugin (flutter_screen_recording) ignores the path parameter
      // and always saves to externalCacheDir or cacheDir with the given name.
      // We just pass a simple filename (no full path, no extension).
      final videoName = 'rec_${DateTime.now().millisecondsSinceEpoch}';
      bool started = await FlutterScreenRecording.startRecordScreenAndAudio(videoName);
      print('FlutterScreenRecording result: $started');
      
      if (started) {
        print('Recording engine started.');
        state = state.copyWith(status: RecordingStatus.recording, duration: Duration.zero);
        _startTimer();
        
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          flag: OverlayFlag.defaultFlag,
          alignment: OverlayAlignment.centerRight,
        );
      }
    } catch (e) {
      print('CRITICAL ERROR in startRecording: $e');
      state = state.copyWith(
        status: RecordingStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> stopRecording() async {
    print('Stop recording requested...');
    try {
      // stopRecordScreen returns the actual full path where the plugin saved the file
      String path = await FlutterScreenRecording.stopRecordScreen;
      print('Plugin returned path: $path');
      _stopTimer();

      final File file = File(path);
      final bool exists = await file.exists();
      final int size = exists ? await file.length() : 0;
      print('File exists: $exists, size: $size bytes');

      if (!exists || size == 0) {
        print('WARNING: File not found or empty at: $path');
        state = state.copyWith(
          status: RecordingStatus.failure,
          errorMessage: '녹화 파일이 생성되지 않았습니다. (경로: $path)',
        );
        return;
      }

      state = state.copyWith(status: RecordingStatus.success, filePath: path);

      // Save to system gallery using native platform channel (most reliable)
      try {
        const channel = MethodChannel('com.smartrecorder/gallery');
        final savedPath = await channel.invokeMethod<String>(
          'saveToGallery',
          {'filePath': path},
        );
        print('Saved to system gallery successfully! Path: $savedPath');
      } on PlatformException catch (e) {
        print('Platform channel gallery save failed: ${e.code} / ${e.message}');
      } catch (e) {
        print('Unknown gallery save error: $e');
      }

      // Close overlay
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }

      // Refresh our in-app gallery
      ref.read(galleryProvider.notifier).refresh();
    } catch (e) {
      print('CRITICAL ERROR in stopRecording: $e');
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
