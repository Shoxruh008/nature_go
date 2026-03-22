package com.example.nature_go

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "app/file_picker"
    private val FILE_PICK_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFile" -> {
                    pendingResult = result
                    openFilePicker()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openFilePicker() {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "*/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                "application/gpx+xml",
                "application/vnd.google-earth.kml+xml",
                "application/geo+json",
                "application/json",
                "application/xml",
                "text/xml",
                "text/plain",
                "*/*"
            ))
        }

        try {
            startActivityForResult(
                Intent.createChooser(intent, "Marshrut faylini tanlang"),
                FILE_PICK_CODE
            )
        } catch (e: Exception) {
            pendingResult?.error("NO_APP", "Fayl menejer topilmadi", e.message)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != FILE_PICK_CODE) return

        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.error("CANCELLED", "Foydalanuvchi bekor qildi", null)
            return
        }

        val uri: Uri = data.data!!

        try {
            val fileName = getFileName(uri) ?: "route_${System.currentTimeMillis()}"
            val tempFile = File(cacheDir, fileName)
            if (tempFile.exists()) tempFile.delete()

            val inputStream = contentResolver.openInputStream(uri)
                ?: run {
                    result.error("READ_ERROR", "Faylni o'qib bo'lmadi", null)
                    return
                }

            inputStream.use { input ->
                FileOutputStream(tempFile).use { output ->
                    input.copyTo(output, bufferSize = 8192)
                }
            }

            if (!tempFile.exists() || tempFile.length() == 0L) {
                result.error("EMPTY_FILE", "Fayl bo'sh", null)
                return
            }

            result.success(mapOf(
                "path" to tempFile.absolutePath,
                "name" to fileName,
                "size" to tempFile.length()
            ))

        } catch (e: SecurityException) {
            result.error("PERMISSION", "Ruxsat yo'q: ${e.message}", null)
        } catch (e: Exception) {
            result.error("ERROR", "${e.message}", null)
        }
    }

    private fun getFileName(uri: Uri): String? {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) return cursor.getString(idx)
                    }
                }
            } catch (e: Exception) {}
        }
        return uri.path?.substringAfterLast('/')?.ifBlank { null }
    }
}