import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartphone_recorder/core/app_theme.dart';
import 'package:smartphone_recorder/presentation/providers/gallery_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryState = ref.watch(galleryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GALLERY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(galleryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: galleryState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (files) {
          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text('녹화된 영상이 없습니다', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return _VideoThumbnail(file: file);
            },
          );
        },
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final File file;

  const _VideoThumbnail({required this.file});

  @override
  Widget build(BuildContext context) {
    if (!file.existsSync()) {
      return const SizedBox.shrink(); // 파일이 없으면 그리지 않음
    }

    final fileName = file.path.split('/').last;
    DateTime date;
    try {
      date = file.lastModifiedSync();
    } catch (e) {
      date = DateTime.now(); // 실패 시 현재 시간으로 대체
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(file: file),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassWhite),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.play_circle_outline, size: 48, color: AppTheme.accentOrange),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute}',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      return IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _showDeleteDialog(context, ref, file),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryNavy,
        title: const Text('영상 삭제', style: TextStyle(color: Colors.white)),
        content: const Text('이 영상을 삭제하시겠습니까?\n시스템 갤러리에서도 사라집니다.', 
                           style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              ref.read(galleryProvider.notifier).deleteFile(file);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('영상이 삭제되었습니다.')),
              );
            },
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final File file;

  const VideoPlayerScreen({super.key, required this.file});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.file.path.split('/').last),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.shareXFiles([XFile(widget.file.path)]);
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _showDeleteDialog(context, ref, widget.file);
                },
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    _ControlsOverlay(controller: _controller),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryNavy,
        title: const Text('영상 삭제', style: TextStyle(color: Colors.white)),
        content: const Text('이 영상을 삭제하시겠습니까?\n시스템 갤러리에서도 사라집니다.', 
                           style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              ref.read(galleryProvider.notifier).deleteFile(file);
              Navigator.pop(context); // 팝업 닫기
              Navigator.pop(context); // 재생 화면 닫기
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('영상이 삭제되었습니다.')),
              );
            },
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;

  const _ControlsOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 50),
      reverseDuration: const Duration(milliseconds: 200),
      child: controller.value.isPlaying
          ? const SizedBox.shrink()
          : Container(
              color: Colors.black26,
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 100.0,
                  semanticLabel: 'Play',
                ),
              ),
            ),
    );
  }
}
