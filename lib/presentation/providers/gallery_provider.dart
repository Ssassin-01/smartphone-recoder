import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class GalleryNotifier extends Notifier<AsyncValue<List<File>>> {
  @override
  AsyncValue<List<File>> build() {
    Future.microtask(() => refresh());
    return const AsyncValue.loading();
  }

  Future<void> refresh() async {
    print('--- Refreshing Gallery ---');
    state = const AsyncValue.loading();
    try {
      final List<File> allFiles = [];

      // 플러그인 소스 분석 결과:
      // flutter_screen_recording은 항상 externalCacheDir 또는 cacheDir에 저장함
      // 그 경로를 정확히 탐색해야 함
      final externalStorage = await getExternalStorageDirectory();
      
      // 플러그인이 실제로 쓰는 경로들을 정확히 추가
      final List<String> searchPaths = [
        // externalCacheDir 패턴: /storage/emulated/0/Android/data/[패키지명]/cache
        if (externalStorage != null)
          externalStorage.path.replaceAll('/files', '/cache'),
        // cacheDir 패턴: /data/user/0/[패키지명]/cache
        (await getTemporaryDirectory()).path,
        // 시스템 갤러리 경로 추가 (DCIM/SmartRecorder)
        '/storage/emulated/0/DCIM/SmartRecorder',
        // 혹시 모를 app_flutter 경로
        (await getApplicationDocumentsDirectory()).path,
      ];

      for (final dirPath in searchPaths) {
        final dir = Directory(dirPath);
        print('Scanning: $dirPath');
        if (!await dir.exists()) {
          print('  -> Does not exist, skipping.');
          continue;
        }

        final List<FileSystemEntity> entities = await dir.list().toList();
        print('  -> Found ${entities.length} items.');

        final List<File> mp4s = entities
            .whereType<File>()
            .where((file) {
              try {
                return file.path.toLowerCase().endsWith('.mp4') && file.existsSync();
              } catch (_) {
                return false;
              }
            })
            .toList();

        print('  -> Found ${mp4s.length} mp4 files.');
        for (var f in mp4s) {
          print('     File: ${f.path}');
        }
        allFiles.addAll(mp4s);
      }

      allFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      print('Total MP4 files found: ${allFiles.length}');
      state = AsyncValue.data(allFiles);
    } catch (e, stack) {
      print('Error refreshing gallery: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteFile(File file) async {
    try {
      // 네이티브 채널로 파일 삭제 + MediaStore 동기화
      const channel = MethodChannel('com.smartrecorder/gallery');
      await channel.invokeMethod('deleteFromGallery', {'filePath': file.path});
      print('Deleted from gallery and MediaStore: ${file.path}');
      refresh();
    } catch (e) {
      // 네이티브 삭제 실패 시 직접 파일 삭제 시도
      print('Native delete failed, trying direct delete: $e');
      try {
        if (await file.exists()) await file.delete();
        refresh();
      } catch (e2) {
        print('Error deleting file: $e2');
      }
    }
  }
}

final galleryProvider =
    NotifierProvider<GalleryNotifier, AsyncValue<List<File>>>(() {
  return GalleryNotifier();
});
