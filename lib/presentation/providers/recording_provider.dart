import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:smartphone_recorder/presentation/providers/gallery_provider.dart';
import 'package:gal/gal.dart';
import 'package:shake/shake.dart';

enum RecordingStatus { idle, countdown, recording, paused, success, failure }

class RecordingState {
  final RecordingStatus status;
  final String? filePath;
  final Duration duration;
  final int countdownSeconds;
  final String? errorMessage;

  RecordingState({
    this.status = RecordingStatus.idle,
    this.filePath,
    this.duration = Duration.zero,
    this.countdownSeconds = 0,
    this.errorMessage,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    String? filePath,
    Duration? duration,
    int? countdownSeconds,
    String? errorMessage,
  }) {
    return RecordingState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class RecordingNotifier extends Notifier<RecordingState> {
  Timer? _timer;
  Timer? _countdownTimer;
  ShakeDetector? _shakeDetector;

  @override
  RecordingState build() {
    _initOverlayListener();
    _initShakeDetector();

    // 앱 생명주기 감시 (강제 종료 대응)
    final observer = _AppLifecycleObserver(onDetached: () {
      if (state.status == RecordingStatus.recording) {
        stopRecording();
      }
    });
    WidgetsBinding.instance.addObserver(observer);
    
    // Clean up when provider is disposed
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(observer);
      _timer?.cancel();
      _countdownTimer?.cancel();
      _shakeDetector?.stopListening();
    });
    
    return RecordingState();
  }

  void _initShakeDetector() {
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (event) {
        if (state.status == RecordingStatus.recording) {
          print('Phone shake detected! Stopping recording...');
          stopRecording();
        }
      },
      shakeThresholdGravity: 2.7,
    );
  }

  void _initOverlayListener() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == 'stop') {
        stopRecording();
      } else if (data == 'start') {
        startRecording();
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
    // 오버레이 권한 체크: 없으면 설정 화면으로 보냄
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    if (state.status == RecordingStatus.recording) return;

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

      // 권한 확인 완료 → 카운트다운 시작 (녹화는 아직 안 함)
      state = state.copyWith(
        status: RecordingStatus.countdown,
        countdownSeconds: 3,
        duration: Duration.zero,
      );

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (state.countdownSeconds > 1) {
          state = state.copyWith(countdownSeconds: state.countdownSeconds - 1);
        } else {
          timer.cancel();
          _countdownTimer = null;

          // 카운트다운 완료 → 이제 실제 녹화 시작 (시스템 권한창이 여기서 뜸)
          await _executeStartRecording();
        }
      });
    } catch (e) {
      print('CRITICAL ERROR in startRecording: $e');
      state = state.copyWith(
        status: RecordingStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> showOverlay() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        print('🟠 [Overlay] 기존 오버레이 종료 후 재시작...');
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final dpr = view.devicePixelRatio;
      const int windowDp = 60;

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true, // 안드로이드 네이티브 드래그 위임
        overlayTitle: "Smart Recorder",
        overlayContent: "녹화 준비 완료",
        width: windowDp,
        height: windowDp,
        alignment: OverlayAlignment.topLeft, // 좌상단 기준 좌표계 사용
        positionGravity: PositionGravity.auto, // 손 뗄 때 좌/우 엣지로 자동 스냅!
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.defaultFlag,
      );
      print('🟠 [Overlay] 오버레이 표시 완료!');
    } catch (e) {
      print('🔴 [Overlay] showOverlay 오류: $e');
    }
  }

  Future<void> _executeStartRecording() async {
    try {
      print('Calling FlutterScreenRecording.startRecordScreenAndAudio...');
      final videoName = 'rec_${DateTime.now().millisecondsSinceEpoch}';
      bool started = await FlutterScreenRecording.startRecordScreenAndAudio(videoName);
      print('FlutterScreenRecording result: $started');
      
      if (started) {
        print('Recording engine started.');
        state = state.copyWith(status: RecordingStatus.recording, duration: Duration.zero);
        _startTimer();
        await showOverlay();
      } else {
        state = state.copyWith(
          status: RecordingStatus.failure,
          errorMessage: '녹화 엔진을 시작하지 못했습니다.',
        );
      }
    } catch (e) {
      print('Error in _executeStartRecording: $e');
      state = state.copyWith(
        status: RecordingStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> stopRecording() async {
    print('Stop recording requested...');
    try {
      String path = await FlutterScreenRecording.stopRecordScreen;
      print('Plugin returned path: $path');
      _stopTimer();
      
      // 오버레이 종료
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }

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
        
        // 원본 캐시 파일 삭제 (중복 방지 및 싱크 최적화)
        if (await File(path).exists()) {
          await File(path).delete();
          print('Original cache file deleted: $path');
        }
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
      final newDuration = state.duration + const Duration(seconds: 1);
      state = state.copyWith(duration: newDuration);
      
      // 오버레이로 실시간 데이터 전송
      final minutes = newDuration.inMinutes.toString().padLeft(2, '0');
      final seconds = (newDuration.inSeconds % 60).toString().padLeft(2, '0');
      FlutterOverlayWindow.shareData({
        'status': 'recording',
        'duration': '$minutes:$seconds',
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    
    // 오버레이 상태 초기화 전송
    FlutterOverlayWindow.shareData({
      'status': 'idle',
      'duration': '00:00',
    });
  }
}

final recordingProvider = NotifierProvider<RecordingNotifier, RecordingState>(() {
  return RecordingNotifier();
});

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onDetached;
  _AppLifecycleObserver({required this.onDetached});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      onDetached();
    }
  }
}
