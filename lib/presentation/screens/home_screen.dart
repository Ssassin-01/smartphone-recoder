import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartphone_recorder/core/app_theme.dart';
import 'package:smartphone_recorder/presentation/providers/recording_provider.dart';
import 'package:smartphone_recorder/presentation/screens/gallery_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingProvider);
    final recordingNotifier = ref.read(recordingProvider.notifier);

    // Listen for status changes to show SnackBars
    ref.listen(recordingProvider, (previous, next) {
      if (next.status == RecordingStatus.success && next.filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('녹화 완료! 저장 위치: ${next.filePath!.split('/').last}'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (next.status == RecordingStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: ${next.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMARTPHONE RECORDER'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Top Section - Status or Visual
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.glassWhite),
                ),
                child: Column(
                  children: [
                    Icon(
                      recordingState.status == RecordingStatus.recording 
                          ? Icons.stop_circle_outlined 
                          : Icons.videocam_outlined,
                      size: 80,
                      color: recordingState.status == RecordingStatus.recording 
                          ? Colors.red 
                          : AppTheme.accentOrange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      recordingState.status == RecordingStatus.failure
                          ? '오류 발생: ${recordingState.errorMessage}'
                          : (recordingState.status == RecordingStatus.countdown
                              ? '${recordingState.countdownSeconds}' 
                              : (recordingState.status == RecordingStatus.recording 
                                  ? '녹화 중... (${_formatDuration(recordingState.duration)})' 
                                  : '녹화 준비 완료')),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: recordingState.status == RecordingStatus.countdown ? 80 : 22,
                        fontWeight: FontWeight.bold,
                        color: recordingState.status == RecordingStatus.failure 
                            ? Colors.red 
                            : (recordingState.status == RecordingStatus.countdown ? AppTheme.accentOrange : Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recordingState.status == RecordingStatus.countdown
                          ? '곧 녹화가 시작됩니다'
                          : (recordingState.status == RecordingStatus.recording 
                              ? '플로팅 버튼이나 휴대폰을 흔들어 중지하세요'
                              : '버튼을 눌러 화면 녹화를 시작하세요'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              // Record Button
              GestureDetector(
                onTap: () {
                  if (recordingState.status == RecordingStatus.recording) {
                    recordingNotifier.stopRecording();
                  } else if (recordingState.status == RecordingStatus.idle || 
                             recordingState.status == RecordingStatus.success || 
                             recordingState.status == RecordingStatus.failure) {
                    recordingNotifier.startRecording();
                  }
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: recordingState.status == RecordingStatus.recording 
                        ? Colors.red 
                        : AppTheme.accentOrange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (recordingState.status == RecordingStatus.recording 
                            ? Colors.red 
                            : AppTheme.accentOrange).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    recordingState.status == RecordingStatus.recording 
                        ? Icons.stop 
                        : Icons.fiber_manual_record,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.settings, '설정', () {}),
                  _buildActionButton(Icons.history, '갤러리', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GalleryScreen()),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.glassWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
