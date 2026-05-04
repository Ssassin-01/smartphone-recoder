package com.example.smartphone_recorder

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smartrecorder/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToGallery" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val savedPath = saveVideoToGallery(filePath)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                "deleteFromGallery" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        deleteVideoFromGallery(filePath)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DELETE_FAILED", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun saveVideoToGallery(sourcePath: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) throw Exception("Source file not found: $sourcePath")

        val fileName = "SmartRecorder_${System.currentTimeMillis()}.mp4"

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+: MediaStore API 사용
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_DCIM}/SmartRecorder")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("Failed to create MediaStore entry")

            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(sourceFile).use { input ->
                    input.copyTo(output)
                }
            }

            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            uri.toString()
        } else {
            // Android 9 이하: DCIM 폴더에 직접 복사 후 미디어 스캔
            val dcimDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
            val targetDir = File(dcimDir, "SmartRecorder").apply { mkdirs() }
            val targetFile = File(targetDir, fileName)

            FileInputStream(sourceFile).use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }

            // 시스템 미디어 스캐너에 등록
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(targetFile.absolutePath),
                arrayOf("video/mp4"),
                null
            )

            targetFile.absolutePath
        }
    }

    private fun deleteVideoFromGallery(filePath: String) {
        val file = File(filePath)
        val resolver = contentResolver
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI

        // MediaStore에서 파일 경로로 항목을 찾아 content URI를 얻은 뒤 삭제
        var deletedFromMediaStore = false
        try {
            val projection = arrayOf(MediaStore.Video.Media._ID)
            val selection = "${MediaStore.Video.Media.DATA} = ?"
            val selectionArgs = arrayOf(filePath)

            resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID))
                    val contentUri = android.net.Uri.withAppendedPath(collection, id.toString())
                    val count = resolver.delete(contentUri, null, null)
                    println("Deleted via content URI: $count row(s) for id=$id")
                    deletedFromMediaStore = count > 0
                }
            }
        } catch (e: Exception) {
            println("MediaStore query/delete error: ${e.message}")
        }

        // MediaStore에서 못 찾았거나 Android 9 이하면 DISPLAY_NAME으로도 시도
        if (!deletedFromMediaStore) {
            val count = resolver.delete(
                collection,
                "${MediaStore.Video.Media.DISPLAY_NAME} = ?",
                arrayOf(file.name)
            )
            println("Fallback DISPLAY_NAME delete: $count row(s) for ${file.name}")
        }

        // 실제 파일 삭제
        if (file.exists()) {
            file.delete()
            println("Physical file deleted: $filePath")
        }

        // Android 9 이하: 미디어 스캔으로 갤러리 갱신
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            MediaScannerConnection.scanFile(applicationContext, arrayOf(filePath), arrayOf("video/mp4"), null)
        }
    }
}
