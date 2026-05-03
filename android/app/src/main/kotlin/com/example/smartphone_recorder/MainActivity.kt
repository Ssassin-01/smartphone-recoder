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
            if (call.method == "saveToGallery") {
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
            } else {
                result.notImplemented()
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
}
